/**
 * firecrawl-guard — 把 Firecrawl 的静默失败变成显式失败。
 *
 * 问题：自建 Firecrawl 抓到 Cloudflare 等 403 反爬页时仍返回 success:true，
 * 正文只有几百字符的 "Just a moment..." 拦截页（实测 611 字符）。模型看到
 * "成功"却拿不到内容，就凭训练记忆编出具体数字（实测编出 npm 版本 0.75.5）。
 *
 * 修法：在 tool_result 阶段改写结果，让"没抓到"这件事无法被误读成"抓到了"。
 *   - 逐条判定 markdown：空 / 过短 / 命中拦截页特征 → 正文替换为显式失败标记
 *   - 请求了正文的来源全部失败 → isError:true，并明确禁止凭记忆作答
 *   - 只有 snippet（没有 markdown 字段）的普通搜索不受影响
 */
import { strict as assert } from "node:assert";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MIN_CONTENT = 500;

const BLOCK_MARKERS = [
	"performing security verification",
	"just a moment",
	"ray id:",
	"enable javascript and cookies to continue",
	"attention required! | cloudflare",
	"verify you are human",
	"checking your browser",
	// OpenReview 的浏览器校验页恰好 500 字符，长度阈值拦不住，只能靠特征串。
	"verifying your browser",
	"complete the check below",
	"please complete the verification",
	"ddos protection by",
];

const FAILED =
	"[[SCRAPE_FAILED]] 未取到可读正文（空或反爬拦截页）。此来源不可作为事实依据，禁止据此推断任何具体数值。";

type WebResult = { url?: string; title?: string; description?: string; markdown?: string };

function isBlocked(markdown: string): boolean {
	const md = markdown.trim();
	if (md.length < MIN_CONTENT) return true;
	const lower = md.toLowerCase();
	return BLOCK_MARKERS.some((marker) => lower.includes(marker));
}

export function emptyMessage(): string {
	return [
		"FIRECRAWL_EMPTY: 搜索后端返回 0 条结果（data.web 为空，常见于 SearXNG 上游被限流、或 includeDomains 过滤过严）。",
		"本次没有检索到任何来源。禁止凭记忆或训练知识回答该问题。",
		"允许的动作：换关键词重试、去掉 includeDomains 重试、或改用官方 JSON API（registry.npmjs.org / api.github.com / pypi.org）。",
	].join("\n");
}

export function guard(data: { web?: WebResult[] }): {
	web: WebResult[];
	failed: string[];
	contentBearing: number;
} {
	const web = data.web ?? [];
	const failed: string[] = [];
	let contentBearing = 0;

	const patched = web.map((item) => {
		// 没请求正文的普通搜索结果：不动它。
		if (!Object.hasOwn(item, "markdown")) return item;
		contentBearing++;
		if (!isBlocked(item.markdown ?? "")) return item;
		failed.push(item.url ?? "(no url)");
		return { ...item, markdown: FAILED };
	});

	return { web: patched, failed, contentBearing };
}

export function guardMessage(failed: string[]): string {
	return [
		`FIRECRAWL_SCRAPE_FAILED: 请求的 ${failed.length} 个来源正文全部抓取失败（空正文或反爬拦截页），本次没有任何可用内容。`,
		"禁止凭记忆或训练知识回答该问题。允许的动作：",
		"1. 改用官方 JSON API：registry.npmjs.org/<pkg>/latest、api.github.com/repos/<o>/<r>/releases/latest、pypi.org/pypi/<pkg>/json",
		"2. 换站点或换关键词重新检索，挑静态 HTML 的来源",
		"3. 直接回答“抓取失败，无法确认”",
		"失败来源：",
		...failed.map((url) => `- ${url}`),
	].join("\n");
}

export default function firecrawlGuard(pi: ExtensionAPI) {
	pi.on("tool_result", async (event) => {
		if (event.toolName !== "firecrawl_search") return;

		const block = event.content.find((c) => c.type === "text");
		if (!block || block.type !== "text") return;

		let parsed: { data?: { web?: WebResult[] } } & Record<string, unknown>;
		try {
			parsed = JSON.parse(block.text);
		} catch {
			return; // 不是我们认识的 JSON，别动
		}
		// 后端返回 0 条（success:true + data:{}）同样是静默失败，必须显式化。
		if (!Array.isArray(parsed.data?.web) || parsed.data.web.length === 0) {
			return { isError: true, content: [{ type: "text", text: emptyMessage() }] };
		}

		const { web, failed, contentBearing } = guard(parsed.data);
		if (failed.length === 0) return;

		// 请求了正文且全军覆没 → 硬错误，模型无法把空壳当内容用。
		if (failed.length === contentBearing) {
			return {
				isError: true,
				content: [{ type: "text", text: guardMessage(failed) }],
			};
		}

		// 部分失败 → 保留可用来源，失败的那些正文已被替换成显式标记。
		return {
			content: [
				{
					type: "text",
					text: JSON.stringify({ ...parsed, data: { ...parsed.data, web } }, null, 2),
				},
			],
		};
	});
}

if (import.meta.main) {
	const ok = "x".repeat(600);
	const { web, failed, contentBearing } = guard({
		web: [
			{ url: "good", markdown: ok },
			{ url: "empty", markdown: "" },
			{ url: "cloudflare", markdown: "Just a moment... Ray ID: abc123" },
			{ url: "snippet-only" },
		],
	});
	assert.equal(contentBearing, 3);
	assert.deepEqual(failed, ["empty", "cloudflare"]);
	assert.equal(web[0].markdown, ok);
	assert.ok(web[1].markdown?.startsWith("[[SCRAPE_FAILED]]"));
	assert.equal(web[3].markdown, undefined, "snippet-only 结果不应被改动");
	assert.ok(guardMessage(failed).includes("registry.npmjs.org"));

	const all = guard({ web: [{ url: "a", markdown: "" }] });
	assert.equal(all.failed.length, all.contentBearing, "全部失败应触发硬错误分支");
	const none = guard({ web: [{ url: "a" }] });
	assert.equal(none.failed.length, 0, "未请求正文时不应报错");
	assert.ok(emptyMessage().includes("FIRECRAWL_EMPTY"));

	// OpenReview 校验页：恰好 500 字符，必须靠特征串拦住。
	const openreview = "[**OpenReview**.net](https://api2.openreview.net/)\n\nVerifying your browser\n=====\n\nComplete the check below to continue to OpenReview\n\nPlease complete the verification above." + "x".repeat(400);
	assert.ok(openreview.length >= 500, "样本必须不短于长度阈值");
	assert.equal(guard({ web: [{ url: "or", markdown: openreview }] }).failed.length, 1, "OpenReview 校验页必须被判失败");
	console.log("firecrawl-guard self-check ok");
}
