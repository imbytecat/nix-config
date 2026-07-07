# Nix Config —— 领域术语

本仓是 nix-darwin + NixOS + Home Manager 声明式管理多主机的单上下文配置。此表只收本仓特有的
领域名词；通用编程 / Nix 概念不入表。命名（issue 标题、重构提案、模块名）请用这里的词，避免漂移到
_Avoid_ 列出的同义词。

## 主机角色

**桌面角色（Desktop role）**：
「带 GUI 桌面」的主机角色 = DE + 桌面应用 + 输入法 + 字体，分系统层（`modules/desktop/{darwin,nixos}.nix`，
按主机加进模块列表）与 home 层（`home/desktop/`，仅 linux 导入、内部按 DE 自我收窄）两层。与无头开发机 /
服务器角色相对。
_Avoid_: 裸「desktop」（会和这两层混指）

## AI 编码代理工具链

**AI 网关（AI gateway）**：
所有编码代理统一路由经过的 OpenAI-compatible LLM 端点（当前 Furtherverse）。承载 provider 与模型
路由；密钥永远走环境变量、不落配置字面量。与网络层的「网关」是两回事，故始终带「AI」前缀。
_Avoid_: LLM API、proxy、裸「网关」

**模型目录（Model catalog）**：
AI 网关端点、provider 身份、跨编码代理引用的模型 ID 与元数据的唯一真源。每个代理配置
（codex / opencode / claude-code）与 shell 密钥模板都是它的 adapter，各自渲染成 TOML / JSON / env。
_Avoid_: 模型列表、providers 表、model config

## 网络

**网关（Gateway）**：
单臂透明代理主机（mihomo-gateway）及其模块（modules/gateway）。裸用「网关」一词一律指它；LLM
端点必须叫「AI 网关」以区分。
_Avoid_: 路由器；proxy（本仓 proxy 专指 mihomo 出站代理，不指本机角色）
