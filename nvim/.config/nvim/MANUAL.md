# Jasper's Neovim Manual

这份手册描述的是当前仓库里这版 `nvim` 配置的实际状态。

目标不是“插件越少越好”，而是：

- 足够极简
- 足够稳定
- 足够适合 `macbook -> ssh -> tmux -> nvim` 的远程开发
- 能把 `Codex` 真正融进编辑器工作流

当前这版的原则是：

- 保留真正高频、真正提升效率的能力
- 删除“看起来高级，但日常收益低”的东西
- 尽量统一按键逻辑，减少模式切换时的脑内负担

## 1. 当前编辑器哲学

这版配置的核心不是模仿 VS Code，而是保留三个高价值能力：

- 强搜索：`Telescope`
- 强结构导航：`LSP + Treesitter + Aerial`
- 强协作/代理：`Codex`

同时把一些不必要的界面层删掉：

- 已删除 `bufferline.nvim`
- 已删除 `todo-comments.nvim`

保留 `nvim-tree` 的原因很明确：

- 你有“先浏览目录，再决定打开哪个文件”的场景
- 你会频繁改名、移动文件
- 对你来说，文件树不是装饰，而是工作流入口

所以现在的结构是：

- 用 `Telescope` 处理“我知道我要找什么”
- 用 `nvim-tree` 处理“我需要先浏览项目结构”
- 用 `Codex` 处理“我想边写边协作/生成/修改”

## 2. 核心习惯

### Leader

- `Leader` 是空格，也就是 `<Space>`

### 模式退出

为了减少对实体 `Esc` 的依赖，当前统一采用：

- `insert mode`: `jk` 退出到 normal mode
- `terminal mode`: `jk` 退出到 normal mode

这套方案对远程开发尤其合适，因为：

- 避免频繁按 `Esc`
- 避免在 `Codex` 这种 TUI 里把 `Esc` 误发进去
- 心智模型统一

注意：

- 这意味着你在插入模式里输入连续的 `jk` 会触发退出

### 窗口切换

普通窗口切换：

- `Ctrl-h`: 切到左侧窗口
- `Ctrl-j`: 切到下方窗口
- `Ctrl-k`: 切到上方窗口
- `Ctrl-l`: 切到右侧窗口

终端窗口切换：

- `Ctrl-g h`: 切到左侧窗口
- `Ctrl-g j`: 切到下方窗口
- `Ctrl-g k`: 切到上方窗口
- `Ctrl-g l`: 切到右侧窗口

为什么终端里不用 `Ctrl-h/j/k/l`：

- `Codex` 自己占用了部分 `Ctrl` 键
- 尤其 `Ctrl-j` 在 Codex 里是换行

所以终端里统一用 `Ctrl-g + 方向键母`。

## 3. 当前插件清单

### 基础界面

- `catppuccin`
  - 当前使用 `latte`
  - 浅色主题
  - 透明背景

- `which-key.nvim`
  - 用于显示 Leader 键提示

- `mini.statusline`
  - 提供简洁状态栏

### 编辑增强

- `blink.cmp`
  - 自动补全

- `LuaSnip`
  - snippet 支持

- `nvim-autopairs`
  - 自动补全括号/引号

- `mini.ai`
  - 更强的文本对象

- `mini.surround`
  - 使用 `gz*` 系列映射管理 surrounding

- `flash.nvim`
  - 快速跳转

### 代码能力

- `nvim-lspconfig`
  - LSP 主入口

- `mason.nvim`
  - 管理 LSP / formatter 工具

- `mason-tool-installer.nvim`
  - 安装工具链

- `fidget.nvim`
  - LSP 状态提示

- `conform.nvim`
  - 格式化

- `nvim-treesitter`
  - 语法树和高亮基础

- `aerial.nvim`
  - 大纲视图

### 搜索与浏览

- `telescope.nvim`
  - 文件搜索 / grep / buffer / diagnostics / keymaps

- `nvim-tree.lua`
  - 项目树浏览与文件管理

### Git 与协作

- `gitsigns.nvim`
  - Git hunk 操作

- `rhart92/codex.nvim`
  - 在右侧栏嵌入 Codex CLI

### 视觉与细节

- `indent-blankline.nvim`
  - 缩进线

## 4. 当前已删除的东西

以下插件已经移除：

- `bufferline.nvim`
- `todo-comments.nvim`

删除后的替代工作流：

- Buffer 切换：`[b` / `]b` / `Telescope buffers`
- TODO 浏览：依赖搜索，而不是单独高亮

## 5. 全局键位手册

### 基础编辑

- `jk`
  - insert mode 下退出到 normal

- `J`
  - 向下跳 5 行

- `K`
  - 向上跳 5 行

- `<Esc>`
  - 清除搜索高亮

- `Ctrl-s`
  - 保存当前文件

- `<leader>r`
  - 重新加载 Neovim 配置

### 诊断

- `<leader>q`
  - 打开 diagnostics loclist

- `[d`
  - 上一个诊断

- `]d`
  - 下一个诊断

- `gl`
  - 打开当前行诊断浮窗

### Buffer

- `[b`
  - 上一个 buffer

- `]b`
  - 下一个 buffer

- `<leader>bd`
  - 删除当前 buffer

### 窗口

- `Ctrl-h/j/k/l`
  - 在 normal mode 下切换窗口

- `Ctrl-g h/j/k/l`
  - 在 terminal mode 下切换窗口

- `Ctrl-M-Left`
  - 缩小窗口宽度

- `Ctrl-M-Right`
  - 增大窗口宽度

- `Ctrl-M-Down`
  - 缩小窗口高度

- `Ctrl-M-Up`
  - 增大窗口高度

### 终端

- `jk`
  - terminal mode 下退出到 normal

- `<leader>ft`
  - 打开/关闭内置浮动终端

## 6. Telescope 手册

这是当前配置里最核心的“快速入口”。

- `<leader><leader>`
  - 搜索文件

- `<leader>sg`
  - 全局 grep

- `<leader>sw`
  - 搜索光标下单词

- `<leader>s/`
  - 仅在已打开文件里 grep

- `<leader>sb`
  - 搜索已打开的 buffers

- `<leader>s.`
  - 最近文件

- `<leader>sd`
  - 搜索 diagnostics

- `<leader>sh`
  - 搜索帮助文档

- `<leader>sk`
  - 搜索键位

- `<leader>ss`
  - 搜索 Telescope 自己的 picker

- `<leader>sr`
  - 恢复上一个 picker

- `<leader>sn`
  - 搜索 Neovim 配置文件

- `<leader>/`
  - 当前 buffer 内模糊搜索

如果你已经知道文件名、路径关键字、内容关键字，优先用 Telescope，而不是文件树。

## 7. 文件树手册

文件树入口：

- `<leader>e`
  - 打开或关闭 `nvim-tree`，并尽量定位到当前文件

为什么现在还保留它：

- 你有浏览需求
- 你有频繁 rename / move 的需求
- 它比纯 fuzzy find 更适合“先理解结构”

建议使用策略：

- 知道目标时：优先 Telescope
- 不知道目标时：先开 `nvim-tree`
- 需要浏览目录层级时：`nvim-tree`
- 需要文件管理时：`nvim-tree`

## 8. LSP 手册

LSP 相关键位：

- `gh`
  - hover

- `gd`
  - 跳到 definition

- `gD`
  - 跳到 declaration

- `gr`
  - 跳到 references

- `gi`
  - 跳到 implementation

- `gy`
  - 跳到 type definition

- `<leader>rn`
  - rename symbol

- `<leader>ca`
  - code action

- `<leader>ds`
  - 当前文档 symbols

- `<leader>ws`
  - workspace symbols

- `<leader>th`
  - 切换 inlay hints

当前配置会在存在可执行文件时启用这些 LSP：

- `clangd`
- `pyright`
- `lua_ls`

自动安装工具列表：

- `clangd`
- `pyright`
- `lua-language-server`
- `clang-format`
- `stylua`
- `isort`
- `black`

## 9. 格式化手册

手动格式化：

- `<leader>cf`

自动格式化：

- 当前只在保存时对以下语言启用：
  - `lua`
  - `python`

当前 formatter：

- `lua -> stylua`
- `python -> isort + black`
- `c/cpp -> clang-format`

## 10. Git 手册

Hunk 导航：

- `]h`
  - 下一个 hunk

- `[h`
  - 上一个 hunk

Git 操作：

- `<leader>gs`
  - stage hunk

- `<leader>gr`
  - reset hunk

- `<leader>gS`
  - stage buffer

- `<leader>gu`
  - undo stage hunk

- `<leader>gR`
  - reset buffer

- `<leader>gp`
  - preview hunk

- `<leader>gb`
  - blame 当前行

- `<leader>gd`
  - diff against index

- `<leader>gD`
  - diff against last commit

Toggle：

- `<leader>tb`
  - toggle current line blame

- `<leader>td`
  - toggle deleted lines preview

## 11. Aerial 大纲手册

- `<leader>o`
  - 打开/关闭 outline

适合这些场景：

- 阅读长文件
- 快速跳函数/类
- 边看结构边问 Codex

## 12. Flash 手册

- `s`
  - 快速跳转

这是对普通移动的补充，不是替代。

适合：

- 同屏快速跳
- 减少反复 `/` 搜索

## 13. Mini Surround 手册

当前 surround 映射不是默认的 `s`，而是 `gz*`，这是为了避免和普通编辑冲突。

- `gza`
  - add surround

- `gzd`
  - delete surround

- `gzf`
  - find surround

- `gzF`
  - find left surround

- `gzh`
  - highlight surround

- `gzr`
  - replace surround

- `gzn`
  - update surround n_lines

## 14. Treesitter 手册

Treesitter 当前作为语法高亮与结构能力底座使用。

手动安装 parser：

- `<leader>pt`

当前目标语言：

- bash
- c
- cpp
- json
- lua
- markdown
- markdown_inline
- python
- query
- vim
- vimdoc
- yaml

## 15. Codex 手册

这是当前配置里最重要的增量能力之一。

### 打开方式

- `<leader>m`
  - 打开/关闭右侧 Codex 栏

Codex 当前配置：

- 右侧竖栏
- 宽度约 40%
- 启动 Neovim 后有 UI 时自动启动
- 发送内容后自动聚焦 Codex

### 发送内容

- `<leader>M`
  - 发送当前 buffer 给 Codex

- visual mode 下 `<leader>m`
  - 发送选中内容给 Codex

### 命令

- `:CodexToggle`
- `:CodexBuffer`
- `:CodexSelection`

### 在 Codex 里怎么操作

- `jk`
  - 退出 terminal mode，回到 normal mode

- `Ctrl-g h/j/k/l`
  - 在终端模式下切换到其他窗口

- `Ctrl-j`
  - 在 Codex 输入框中插入新行，不发送

### Codex 工作流建议

最推荐的工作流是：

1. 左边编辑代码
2. 右边开 Codex
3. 选中一段代码后 visual mode 下按 `<leader>m`
4. 在 Codex 里继续追加说明
5. 用 `jk` 回到 normal mode
6. 用 `Ctrl-g h` 切回代码窗口

如果你要让 Codex 帮你看整个文件：

- 直接按 `<leader>M`

如果你要让 Codex 聚焦某一段逻辑：

- 选中后按 `<leader>m`

## 16. 当前 UI / 行为设置

### 外观

- 主题：`catppuccin-latte`
- 背景：light
- 透明背景：开启
- 光标行：开启
- 行号：绝对行号

### 编辑体验

- `tabstop = 4`
- `shiftwidth = 4`
- `expandtab = true`
- `scrolloff = 10`
- `ignorecase = true`
- `smartcase = true`
- `splitright = true`
- `splitbelow = true`
- `timeoutlen = 400`
- `updatetime = 250`
- `undofile = true`
- `clipboard = unnamedplus`

### 列表字符

- tab: `» `
- trail: `·`
- nbsp: `␣`

## 17. 推荐日常工作流

### 打开项目后

建议习惯：

1. `space space` 找文件
2. `space e` 看目录结构
3. `space o` 看代码大纲
4. `space m` 开 Codex 侧栏

### 写代码时

建议习惯：

- 补全交给 `blink.cmp`
- surround 交给 `gz*`
- 跳转优先 `gd/gr/gi/gy`
- 同屏跳转用 `s`

### 在多个文件间切换

优先级建议：

1. `space sb` 已打开 buffers
2. `[b` / `]b`
3. `space .` 最近文件
4. `space space` 重新搜索文件

### 浏览项目结构时

优先级建议：

1. `space e` 打开文件树
2. `space o` 看当前文件结构
3. `space sg` 从内容反查文件

### 与 Codex 协作时

最推荐的组合是：

- `space m`: 打开 Codex
- visual + `space m`: 发选中代码
- `space M`: 发整个 buffer
- `jk`: 退出 terminal mode
- `Ctrl-g h`: 从 Codex 切回左边代码窗口

## 18. 这版配置的优点

- 按键逻辑比较统一
- 对远程开发友好
- 对 Codex 友好
- 该删的界面层已经删掉
- 还保留了浏览目录的能力

## 19. 这版配置的代价

- `jk` 会占掉正常输入 `jk` 的字面组合
- 没有 bufferline 之后，需要接受“buffer 是列表，不是标签页”的工作流
- 仍然保留 `nvim-tree`，所以它不是“插件数量最小”，而是“工作流最稳”

## 20. 下一步如果继续极简

如果后面还要继续精简，最合理的下一步不是乱删，而是按顺序考虑：

1. 优化 `nvim-tree` 使用习惯
2. 评估是否把 `nvim-tree` 换成 `oil.nvim` 或 `mini.files`
3. 评估是否要继续减少视觉插件

当前不建议再随便删除：

- `nvim-tree`
- `telescope`
- `lsp`
- `treesitter`
- `codex`

因为这些已经是你当前工作流的核心基础设施。
