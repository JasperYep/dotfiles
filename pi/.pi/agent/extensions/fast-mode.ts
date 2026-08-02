import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATE_ENTRY = "fast-mode-state";
const STATUS_KEY = "fast-mode";
const GPT_MODEL_RE = /^(?:gpt|chatgpt)(?:[-_.]|$)/i;

type FastModeState = {
  enabled: boolean;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isGptModel(modelId: string | undefined): boolean {
  return !!modelId && GPT_MODEL_RE.test(modelId);
}

export default function fastModeExtension(pi: ExtensionAPI) {
  let enabled = false;

  function updateStatus(ctx: ExtensionContext): void {
    if (!enabled) {
      ctx.ui.setStatus(STATUS_KEY, undefined);
      return;
    }

    const applicable = isGptModel(ctx.model?.id);
    ctx.ui.setStatus(STATUS_KEY, applicable ? "⚡" : undefined);
  }

  function persist(): void {
    pi.appendEntry(STATE_ENTRY, { enabled } satisfies FastModeState);
  }

  function setEnabled(next: boolean, ctx: ExtensionContext): void {
    enabled = next;
    persist();
    updateStatus(ctx);

    if (!enabled) {
      ctx.ui.notify("GPT 快速模式已关闭", "info");
      return;
    }

    if (isGptModel(ctx.model?.id)) {
      ctx.ui.notify(`GPT 快速模式已开启：${ctx.model?.id}`, "info");
    } else {
      ctx.ui.notify("快速模式已开启；切换到 GPT 类模型后生效", "warning");
    }
  }

  pi.registerCommand("fast", {
    description: "切换 GPT 快速模式（OpenAI service_tier=priority）；支持 on/off/status",
    getArgumentCompletions: (prefix) => {
      const options = ["on", "off", "status"];
      const matches = options.filter((option) => option.startsWith(prefix.trim().toLowerCase()));
      return matches.length > 0 ? matches.map((value) => ({ value, label: value })) : null;
    },
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();

      if (action === "status") {
        const model = ctx.model?.id ?? "未选择模型";
        const applicability = isGptModel(ctx.model?.id) ? "当前模型可用" : "当前模型不是 GPT 类模型";
        ctx.ui.notify(`GPT 快速模式：${enabled ? "开启" : "关闭"}；${applicability}；模型：${model}`, "info");
        return;
      }

      if (action === "on") {
        setEnabled(true, ctx);
        return;
      }

      if (action === "off") {
        setEnabled(false, ctx);
        return;
      }

      if (action.length > 0) {
        ctx.ui.notify("用法：/fast [on|off|status]", "warning");
        return;
      }

      setEnabled(!enabled, ctx);
    },
  });

  pi.on("session_start", (_event, ctx) => {
    enabled = false;

    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== STATE_ENTRY) continue;
      if (!isRecord(entry.data) || typeof entry.data.enabled !== "boolean") continue;
      enabled = entry.data.enabled;
    }

    updateStatus(ctx);
  });

  pi.on("model_select", (_event, ctx) => {
    updateStatus(ctx);
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (!enabled || !isGptModel(ctx.model?.id) || !isRecord(event.payload)) return;

    // OpenAI Responses and Chat Completions both accept service_tier at the
    // request top level. "priority" is the API-side fast/priority-processing tier.
    return {
      ...event.payload,
      service_tier: "priority",
    };
  });
}
