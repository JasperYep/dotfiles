import type { Api, Model } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type Phase = "planning" | "executing" | "verifying";

interface WorkflowState {
  phase: Phase;
  task: string;
  originalModel: Model<Api> | undefined;
  originalThinkingLevel: ReturnType<ExtensionAPI["getThinkingLevel"]>;
  originalTools: string[];
}

const PROVIDER = "jasper";
const THINK_MODEL_ID = "gpt-5.6-sol";
const EXEC_MODEL_ID = "gemini-3.6-flash-high";

export default function autoExtension(pi: ExtensionAPI) {
  let workflow: WorkflowState | undefined;
  let transitioning = false;

  function modelLabel(model: Model<Api>): string {
    return `${model.provider}/${model.id}`;
  }

  function selectTools(preferred: string[], fallback: string[]): string[] {
    const available = new Set(pi.getAllTools().map((tool) => tool.name));
    const selected = preferred.filter((name) => available.has(name));
    return selected.length > 0 ? selected : fallback;
  }

  async function setModel(
    ctx: ExtensionContext,
    modelId: string,
    thinkingLevel: "off" | "max",
  ): Promise<Model<Api>> {
    const model = ctx.modelRegistry.find(PROVIDER, modelId);
    if (!model) {
      throw new Error(`找不到模型 ${PROVIDER}/${modelId}`);
    }

    const success = await pi.setModel(model);
    if (!success) {
      throw new Error(`模型 ${PROVIDER}/${modelId} 没有可用认证信息`);
    }

    pi.setThinkingLevel(thinkingLevel);
    return model;
  }

  async function restoreOriginal(ctx: ExtensionContext): Promise<void> {
    if (!workflow) return;

    const { originalModel, originalThinkingLevel, originalTools } = workflow;
    if (originalModel) {
      const restored = await pi.setModel(originalModel);
      if (!restored) {
        ctx.ui.notify(`无法恢复原模型 ${modelLabel(originalModel)}`, "warning");
      }
    }
    pi.setThinkingLevel(originalThinkingLevel);
    if (originalTools.length > 0) pi.setActiveTools(originalTools);
  }

  async function fail(ctx: ExtensionContext, error: unknown): Promise<void> {
    const message = error instanceof Error ? error.message : String(error);
    try {
      await restoreOriginal(ctx);
    } finally {
      workflow = undefined;
      transitioning = false;
      ctx.ui.setStatus("auto", undefined);
      ctx.ui.notify(`/auto 已停止：${message}`, "error");
    }
  }

  async function startPlanning(task: string, ctx: ExtensionContext): Promise<void> {
    const model = await setModel(ctx, THINK_MODEL_ID, "max");
    const planningTools = selectTools(["read", "bash"], workflow!.originalTools);
    pi.setActiveTools(planningTools);
    ctx.ui.setStatus("auto", "AUTO 1/3 planning");
    ctx.ui.notify(`阶段 1/3：${modelLabel(model)} (max) 思考与决策`, "info");

    pi.sendUserMessage(
      [
        "【AUTO 阶段 1/3：思考与决策】",
        `原始任务：${task}`,
        "",
        "请先充分检查相关代码和项目结构，再制定可靠的执行方案。",
        "本阶段禁止修改、创建或删除任何文件，也不要执行会改变项目状态的命令。",
        "输出清晰的实施步骤、涉及文件、风险、边界情况和验证方案。",
      ].join("\n"),
    );
  }

  async function startExecution(ctx: ExtensionContext): Promise<void> {
    const model = await setModel(ctx, EXEC_MODEL_ID, "off");
    pi.setActiveTools(workflow!.originalTools);
    workflow!.phase = "executing";
    ctx.ui.setStatus("auto", "AUTO 2/3 executing");
    ctx.ui.notify(`阶段 2/3：${modelLabel(model)} 执行`, "info");

    pi.sendUserMessage(
      [
        "【AUTO 阶段 2/3：执行】",
        `原始任务：${workflow!.task}`,
        "",
        "严格依据上一阶段的分析和计划实施任务。",
        "请直接使用可用工具完成必要修改；保持范围克制，不做无关改动。",
        "完成后运行适当的基础测试或静态检查，并简要报告实际改动。",
      ].join("\n"),
    );
  }

  async function startVerification(ctx: ExtensionContext): Promise<void> {
    const model = await setModel(ctx, THINK_MODEL_ID, "max");
    const verificationTools = selectTools(["read", "bash"], workflow!.originalTools);
    pi.setActiveTools(verificationTools);
    workflow!.phase = "verifying";
    ctx.ui.setStatus("auto", "AUTO 3/3 verifying");
    ctx.ui.notify(`阶段 3/3：${modelLabel(model)} (max) 严格验证`, "info");

    pi.sendUserMessage(
      [
        "【AUTO 阶段 3/3：严格验证】",
        `原始任务：${workflow!.task}`,
        "",
        "独立审查上一阶段产生的所有修改，不要仅复述执行者的结论。",
        "检查 git diff，运行适当的测试、类型检查或 lint，并核对实现是否满足原始任务。",
        "本阶段只验证，不修改文件。明确报告：验证命令及结果、发现的问题、残余风险，以及最终是否通过。",
      ].join("\n"),
    );
  }

  pi.registerCommand("auto", {
    description: "gpt-5.6-sol(max) 规划和验证，gemini-3.6-flash-high 执行",
    handler: async (args, ctx) => {
      const task = args.trim();
      if (!task) {
        ctx.ui.notify("用法：/auto <具体任务>", "warning");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("当前 Agent 正忙，请等待当前任务结束后再运行 /auto", "warning");
        return;
      }
      if (workflow) {
        ctx.ui.notify("已有 /auto 工作流正在运行", "warning");
        return;
      }

      workflow = {
        phase: "planning",
        task,
        originalModel: ctx.model,
        originalThinkingLevel: pi.getThinkingLevel(),
        originalTools: pi.getActiveTools(),
      };

      try {
        await startPlanning(task, ctx);
      } catch (error) {
        await fail(ctx, error);
      }
    },
  });

  pi.registerCommand("auto-stop", {
    description: "停止当前 /auto 工作流并恢复原模型、思考等级和工具",
    handler: async (_args, ctx) => {
      if (!workflow) {
        ctx.ui.notify("当前没有运行中的 /auto 工作流", "info");
        return;
      }
      if (!ctx.isIdle()) ctx.abort();
      await restoreOriginal(ctx);
      workflow = undefined;
      transitioning = false;
      ctx.ui.setStatus("auto", undefined);
      ctx.ui.notify("/auto 已停止，原配置已恢复", "info");
    },
  });

  pi.on("agent_settled", async (_event, ctx) => {
    if (!workflow || transitioning) return;
    transitioning = true;

    try {
      if (workflow.phase === "planning") {
        await startExecution(ctx);
      } else if (workflow.phase === "executing") {
        await startVerification(ctx);
      } else {
        await restoreOriginal(ctx);
        workflow = undefined;
        ctx.ui.setStatus("auto", undefined);
        ctx.ui.notify("/auto 三阶段工作流已完成，原配置已恢复", "info");
      }
    } catch (error) {
      await fail(ctx, error);
    } finally {
      transitioning = false;
    }
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    if (workflow) await restoreOriginal(ctx);
    workflow = undefined;
    transitioning = false;
  });
}
