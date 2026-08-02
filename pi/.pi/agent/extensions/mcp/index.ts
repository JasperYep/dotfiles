/**
 * MCP bridge for pi.
 *
 * Loads servers from ~/.pi/agent/mcp.json (Claude/Cursor-compatible format),
 * connects over stdio on session_start, and registers each MCP tool as a pi tool.
 *
 * TalkToFigma also needs the WebSocket relay on :3055 and the Figma plugin
 * connected to the same channel. This extension auto-starts the relay if free.
 *
 * Commands:
 *   /mcp            list servers + tool count
 *   /mcp-reconnect  restart MCP connections
 *   /figma-socket   ensure TalkToFigma websocket relay is running
 */

import { spawn, type ChildProcess } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { createConnection } from "node:net";
import { homedir } from "node:os";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type, type TSchema } from "typebox";

type McpServerConfig = {
	command: string;
	args?: string[];
	env?: Record<string, string>;
	cwd?: string;
	/** Optional tool name prefix. Default: sanitized server name + "_" */
	prefix?: string;
	disabled?: boolean;
};

type McpConfigFile = {
	mcpServers?: Record<string, McpServerConfig>;
};

type ConnectedServer = {
	name: string;
	client: Client;
	transport: StdioClientTransport;
	tools: string[];
};

const CONFIG_PATH = join(homedir(), ".pi/agent/mcp.json");
const FIGMA_SOCKET_PORT = 3055;
const FIGMA_SOCKET_CMD = ["bunx", "cursor-talk-to-figma-socket@latest"];

let connected: ConnectedServer[] = [];
let registeredToolNames = new Set<string>();
let socketProc: ChildProcess | null = null;
let socketStartedByUs = false;

function loadConfig(): Record<string, McpServerConfig> {
	if (!existsSync(CONFIG_PATH)) {
		return {};
	}
	try {
		const raw = readFileSync(CONFIG_PATH, "utf8");
		const parsed = JSON.parse(raw) as McpConfigFile;
		return parsed.mcpServers ?? {};
	} catch (err) {
		console.error(`[mcp] failed to read ${CONFIG_PATH}:`, err);
		return {};
	}
}

function sanitizeName(name: string): string {
	return name.replace(/[^a-zA-Z0-9_]/g, "_");
}

function portOpen(port: number, host = "127.0.0.1"): Promise<boolean> {
	return new Promise((resolve) => {
		const socket = createConnection({ port, host });
		socket.once("connect", () => {
			socket.end();
			resolve(true);
		});
		socket.once("error", () => resolve(false));
		socket.setTimeout(500, () => {
			socket.destroy();
			resolve(false);
		});
	});
}

async function ensureFigmaSocket(ctx?: ExtensionContext): Promise<string> {
	if (await portOpen(FIGMA_SOCKET_PORT)) {
		return `Figma websocket relay already listening on :${FIGMA_SOCKET_PORT}`;
	}

	const [cmd, ...args] = FIGMA_SOCKET_CMD;
	socketProc = spawn(cmd, args, {
		stdio: ["ignore", "ignore", "pipe"],
		detached: true,
		env: { ...process.env },
	});
	socketStartedByUs = true;
	socketProc.unref();

	socketProc.stderr?.on("data", (buf: Buffer) => {
		const line = buf.toString().trim();
		if (line) console.error(`[figma-socket] ${line}`);
	});
	socketProc.on("exit", (code) => {
		console.error(`[figma-socket] exited code=${code}`);
		socketProc = null;
		socketStartedByUs = false;
	});

	// wait up to ~3s for listen
	for (let i = 0; i < 30; i++) {
		await new Promise((r) => setTimeout(r, 100));
		if (await portOpen(FIGMA_SOCKET_PORT)) {
			const msg = `Started Figma websocket relay on :${FIGMA_SOCKET_PORT}`;
			ctx?.ui.notify(msg, "info");
			return msg;
		}
	}
	return `Started Figma websocket relay process, but :${FIGMA_SOCKET_PORT} not yet accepting connections`;
}

/** Convert a JSON Schema (MCP inputSchema) into a TypeBox schema pi can validate. */
function jsonSchemaToTypebox(schema: unknown): TSchema {
	if (!schema || typeof schema !== "object") {
		return Type.Object({}, { additionalProperties: true });
	}

	const s = schema as Record<string, unknown>;
	const t = s.type;

	if (Array.isArray(t)) {
		// union types e.g. ["string","null"] — treat as any
		return Type.Any();
	}

	switch (t) {
		case "string": {
			const opts: Record<string, unknown> = {};
			if (typeof s.description === "string") opts.description = s.description;
			if (Array.isArray(s.enum) && s.enum.every((x) => typeof x === "string")) {
				return Type.Unsafe({ type: "string", enum: s.enum, ...opts });
			}
			return Type.String(opts);
		}
		case "number":
		case "integer": {
			const opts: Record<string, unknown> = {};
			if (typeof s.description === "string") opts.description = s.description;
			return t === "integer" ? Type.Integer(opts) : Type.Number(opts);
		}
		case "boolean": {
			const opts: Record<string, unknown> = {};
			if (typeof s.description === "string") opts.description = s.description;
			return Type.Boolean(opts);
		}
		case "array": {
			const items = s.items ? jsonSchemaToTypebox(s.items) : Type.Any();
			const opts: Record<string, unknown> = {};
			if (typeof s.description === "string") opts.description = s.description;
			return Type.Array(items, opts);
		}
		case "object":
		default: {
			const propsIn = (s.properties ?? {}) as Record<string, unknown>;
			const required = new Set(
				Array.isArray(s.required) ? (s.required as string[]) : [],
			);
			const props: Record<string, TSchema> = {};
			for (const [key, val] of Object.entries(propsIn)) {
				const child = jsonSchemaToTypebox(val);
				props[key] = required.has(key) ? child : Type.Optional(child);
			}
			const opts: Record<string, unknown> = { additionalProperties: true };
			if (typeof s.description === "string") opts.description = s.description;
			return Type.Object(props, opts);
		}
	}
}

function toolNameFor(serverName: string, toolName: string, prefix?: string): string {
	const p = prefix ?? `${sanitizeName(serverName)}_`;
	const full = `${p}${toolName}`;
	// keep names model-friendly
	return full.replace(/[^a-zA-Z0-9_]/g, "_");
}

async function disconnectAll(): Promise<void> {
	for (const s of connected) {
		try {
			await s.client.close();
		} catch {
			// ignore
		}
		try {
			await s.transport.close();
		} catch {
			// ignore
		}
	}
	connected = [];
}

async function connectServers(
	pi: ExtensionAPI,
	ctx?: ExtensionContext,
): Promise<void> {
	await disconnectAll();

	const servers = loadConfig();
	const names = Object.keys(servers);
	if (names.length === 0) {
		// Empty config is intentional (MCP off). Stay quiet.
		if (ctx) ctx.ui.setStatus("mcp", undefined);
		return;
	}

	// TalkToFigma needs the local websocket relay
	if (names.some((n) => /figma/i.test(n) || /TalkToFigma/i.test(n))) {
		await ensureFigmaSocket(ctx);
	}

	const inheritedEnv = { ...process.env } as Record<string, string>;

	for (const [name, cfg] of Object.entries(servers)) {
		if (cfg.disabled) continue;
		if (!cfg.command) {
			console.error(`[mcp] ${name}: missing command`);
			continue;
		}

		try {
			const transport = new StdioClientTransport({
				command: cfg.command,
				args: cfg.args ?? [],
				env: { ...inheritedEnv, ...(cfg.env ?? {}) },
				cwd: cfg.cwd,
				stderr: "pipe",
			});

			// surface MCP server stderr
			const stderr = transport.stderr;
			stderr?.on("data", (buf: Buffer) => {
				const line = buf.toString().trim();
				if (line) console.error(`[mcp:${name}] ${line}`);
			});

			const client = new Client(
				{ name: "pi-mcp-bridge", version: "0.1.0" },
				{ capabilities: {} },
			);

			await client.connect(transport);

			const listed = await client.listTools();
			const tools = listed.tools ?? [];
			const registered: string[] = [];

			for (const tool of tools) {
				const piName = toolNameFor(name, tool.name, cfg.prefix);
				if (registeredToolNames.has(piName)) {
					// already registered in a previous connect of this session;
					// re-bind execute by re-registering with same name (pi allows override)
				}
				registeredToolNames.add(piName);
				registered.push(piName);

				const parameters = jsonSchemaToTypebox(tool.inputSchema ?? { type: "object" });
				const description =
					tool.description?.trim() ||
					`MCP tool ${tool.name} from server ${name}`;

				pi.registerTool({
					name: piName,
					label: `${name}: ${tool.name}`,
					description: `[MCP:${name}] ${description}`,
					promptSnippet: `MCP ${name}/${tool.name}`,
					promptGuidelines: [
						name.toLowerCase().includes("figma")
							? "For Figma: call TalkToFigma_join_channel first with the same channel as the Figma plugin, then read selection/document before edits."
							: `Call MCP tools from server ${name} when the task needs that integration.`,
					],
					parameters,
					async execute(_toolCallId, params, signal) {
						try {
							const result = await client.callTool(
								{ name: tool.name, arguments: params as Record<string, unknown> },
								undefined,
								{ signal },
							);

							const content = Array.isArray((result as { content?: unknown }).content)
								? ((result as { content: Array<Record<string, unknown>> }).content)
								: [];

							const mapped = content.map((part) => {
								if (part.type === "text" && typeof part.text === "string") {
									return { type: "text" as const, text: part.text };
								}
								if (
									part.type === "image" &&
									typeof part.data === "string" &&
									typeof part.mimeType === "string"
								) {
									// pi content supports images in some paths; keep as text fallback with data URL note
									return {
										type: "text" as const,
										text: `[image ${part.mimeType}, ${part.data.length} base64 chars]`,
									};
								}
								return {
									type: "text" as const,
									text: JSON.stringify(part),
								};
							});

							if (mapped.length === 0) {
								mapped.push({
									type: "text",
									text: JSON.stringify(result, null, 2),
								});
							}

							const isError = Boolean((result as { isError?: boolean }).isError);
							return {
								content: mapped,
								details: { server: name, tool: tool.name, isError },
							};
						} catch (err) {
							const msg = err instanceof Error ? err.message : String(err);
							return {
								content: [
									{
										type: "text",
										text: `MCP error (${name}/${tool.name}): ${msg}`,
									},
								],
								details: { server: name, tool: tool.name, error: msg },
							};
						}
					},
				});
			}

			connected.push({ name, client, transport, tools: registered });
			console.error(`[mcp] connected ${name}: ${registered.length} tools`);
		} catch (err) {
			const msg = err instanceof Error ? err.message : String(err);
			console.error(`[mcp] failed to connect ${name}: ${msg}`);
			ctx?.ui.notify(`MCP ${name} failed: ${msg}`, "error");
		}
	}

	const total = connected.reduce((n, s) => n + s.tools.length, 0);
	if (ctx) {
		ctx.ui.setStatus(
			"mcp",
			connected.length ? `mcp:${connected.length}/${total}` : undefined,
		);
		if (connected.length) {
			ctx.ui.notify(
				`MCP ready: ${connected.map((s) => `${s.name}(${s.tools.length})`).join(", ")}`,
				"info",
			);
		}
	}
}

export default function mcpExtension(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		await connectServers(pi, ctx);
	});

	pi.on("session_shutdown", async () => {
		await disconnectAll();
		// leave socket running if we started it — useful across sessions;
		// only kill if you want strict cleanup. Prefer keep-alive for Figma plugin.
		pi; // keep signature used
	});

	pi.registerCommand("mcp", {
		description: "Show connected MCP servers and tools",
		handler: async (_args, ctx) => {
			if (!connected.length) {
				ctx.ui.notify(`No MCP servers connected. Config: ${CONFIG_PATH}`, "warning");
				return;
			}
			const lines = connected.map(
				(s) => `${s.name}: ${s.tools.length} tools\n  - ${s.tools.join("\n  - ")}`,
			);
			ctx.ui.notify(lines.join("\n\n"), "info");
		},
	});

	pi.registerCommand("mcp-reconnect", {
		description: "Reconnect all MCP servers from ~/.pi/agent/mcp.json",
		handler: async (_args, ctx) => {
			ctx.ui.notify("Reconnecting MCP servers...", "info");
			await connectServers(pi, ctx);
		},
	});

	pi.registerCommand("figma-socket", {
		description: "Ensure TalkToFigma websocket relay is running on :3055",
		handler: async (_args, ctx) => {
			const msg = await ensureFigmaSocket(ctx);
			ctx.ui.notify(msg, "info");
		},
	});
}
