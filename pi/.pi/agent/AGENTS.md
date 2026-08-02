# Global Pi Preferences

## Skills: manual invocation only

- Never automatically load, read, invoke, or execute any skill, even when the user's task matches a skill description.
- Use general reasoning and the normal tools by default when no skill has been explicitly requested.
- Invoke a skill only when the user explicitly enters `/skill:<name>` or directly asks to invoke that named skill.
- When a task would substantially benefit from an available skill, do not load it automatically. Briefly recommend the most relevant skill, include the exact `/skill:<name>` command, and let the user invoke it manually.
- A recommendation is not permission to invoke the skill. Wait for the user's explicit manual invocation.
- Keep skill recommendations selective; do not interrupt ordinary tasks with unnecessary suggestions.
- These rules apply to all current and future skills. Built-in tools and extension tools are not skills and remain available normally.

## 输出规范

- 中英混合输出时，只在中文字符与英文单词相邻的边界不要加空格；英文单词之间必须保留正常空格。例如：不是“不同的 memory architecture”，也不是“不同的memoryarchitecture”，而是“不同的memory architecture”。
