# AI 计划代理

这个轻量代理把 OpenAI API Key 留在服务端，App 只访问 `POST /plan`，避免将密钥写进安装包。

## 本地启动

需要 Node.js 18 或更高版本。在 PowerShell 中运行：

```powershell
$env:OPENAI_API_KEY = "你的 API Key"
node .\ai-proxy\server.mjs
```

然后在 App 的“AI 计划”页填写：

```text
http://127.0.0.1:8787/plan
```

`127.0.0.1` 只适用于代理与 App 位于同一设备的调试场景。真机访问电脑上的代理时，需要把服务监听到局域网地址；正式使用应部署到 HTTPS 域名，并在网关增加身份验证、限流和访问日志脱敏。

可选环境变量：

- `OPENAI_MODEL`：默认 `gpt-5.6-terra`
- `HOST`：默认 `127.0.0.1`
- `PORT`：默认 `8787`

健康检查为 `GET /health`。服务端不会把 OpenAI 的错误响应原样返回给 App，避免泄漏内部信息。
