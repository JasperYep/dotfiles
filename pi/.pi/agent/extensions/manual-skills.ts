import type { ExtensionAPI, Skill } from "@earendil-works/pi-coding-agent";

const AUTO_SKILL_SECTION_START =
	"\n\nThe following skills provide specialized instructions for specific tasks.";
const AUTO_SKILL_SECTION_END = "</available_skills>";

function stripAutomaticSkillSection(systemPrompt: string): string {
	let prompt = systemPrompt;

	while (true) {
		const start = prompt.indexOf(AUTO_SKILL_SECTION_START);
		if (start === -1) return prompt;

		const end = prompt.indexOf(AUTO_SKILL_SECTION_END, start);
		if (end === -1) return prompt;

		prompt =
			prompt.slice(0, start) +
			prompt.slice(end + AUTO_SKILL_SECTION_END.length);
	}
}

function escapeXml(value: string): string {
	return value
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&apos;");
}

function escapeRegExp(value: string): string {
	return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function findDirectlyRequestedSkills(prompt: string, skills: Skill[]): Skill[] {
	const text = prompt.trim();

	return skills.filter((skill) => {
		const name = escapeRegExp(skill.name);
		const chineseRequest = new RegExp(
			`^(?:请(?:你)?\\s*)?(?:调用|使用|启用|执行|运行|指定)(?:一下)?\\s*(?:skill|技能)?\\s*[:：]?\\s*(?:/skill:)?${name}(?:\\s*(?:skill|技能))?(?:\\s|$)`,
			"i",
		);
		const englishRequest = new RegExp(
			`^(?:please\\s+)?(?:invoke|use|activate|run)\\s+(?:the\\s+)?(?:${name}(?:\\s+skill)?|skill\\s+${name})(?:\\s|$)`,
			"i",
		);
		return chineseRequest.test(text) || englishRequest.test(text);
	});
}

function buildManualSkillPolicy(
	skills: Skill[],
	expandedSkillName: string | undefined,
	directlyRequestedSkills: Skill[],
): string {
	const catalog = skills
		.map((skill) => {
			const description = skill.description.replace(/\s+/g, " ").trim();
			return `  <skill name="${escapeXml(skill.name)}">${escapeXml(description)}</skill>`;
		})
		.join("\n");

	let invocationStatus: string;
	if (expandedSkillName) {
		invocationStatus = `The current user message contains the explicitly invoked skill \`${expandedSkillName}\`. Its full instructions are already present in the user message and are authorized for this request.`;
	} else if (directlyRequestedSkills.length > 0) {
		const authorized = directlyRequestedSkills
			.map((skill) => `  - ${skill.name}: ${skill.filePath}`)
			.join("\n");
		invocationStatus = `The user directly requested the following named skill(s). They are authorized for this request; load only these instruction files:\n${authorized}`;
	} else {
		invocationStatus =
			"No skill was explicitly invoked for this request. Do not read a SKILL.md file, load a skill, or execute a skill workflow.";
	}

	return `

## Manual-only skill policy

- Skills must never be invoked automatically based on task matching.
- A skill is authorized only when the current user message contains an explicit \`<skill name="...">\` block produced by the user's \`/skill:<name>\` command, or when the user directly asks to invoke that named skill.
- If a task would substantially benefit from a skill and none was invoked, only recommend the most relevant \`/skill:<name>\` command and let the user invoke it manually.
- A recommendation or a vague confirmation is not authorization to invoke a skill.
- Use general reasoning and normal tools by default.
- ${invocationStatus}

The following catalog is for recommendations only; it is not authorization to load any skill:
<manual_skill_catalog>
${catalog}
</manual_skill_catalog>`;
}

export default function manualSkills(pi: ExtensionAPI) {
	pi.on("before_agent_start", (event) => {
		const skills = event.systemPromptOptions.skills ?? [];
		const expandedSkillName = event.prompt.match(
			/^<skill name="([^"]+)" location="[^"]+">\n/,
		)?.[1];
		const directlyRequestedSkills = expandedSkillName
			? []
			: findDirectlyRequestedSkills(event.prompt, skills);
		const basePrompt = stripAutomaticSkillSection(event.systemPrompt);

		return {
			systemPrompt: `${basePrompt}${buildManualSkillPolicy(
				skills,
				expandedSkillName,
				directlyRequestedSkills,
			)}`,
		};
	});
}
