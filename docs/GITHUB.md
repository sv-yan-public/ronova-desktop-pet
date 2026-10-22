# 上传到 GitHub

此目录为独立本地 Git 仓库，尚未连接远端或上传。

1. 在 GitHub 新建空仓库，建议名称 `ronova-desktop-pet`，按需要选择公开或私有；不要预先生成 README 或许可证。
2. 在本项目目录执行（将 `YOUR_USERNAME` 换成你的 GitHub 用户名）：

```sh
git add .
git commit -m "Initial import of Ronova Desktop Pet"
git remote add origin https://github.com/YOUR_USERNAME/ronova-desktop-pet.git
git push -u origin main
```

如果 Git 尚未配置提交身份，先设置自己的 `user.name` / `user.email`。身份和凭据不要写入项目文件。

也可以使用 GitHub Desktop：添加这个现有本地仓库，创建首次提交，再选择 Publish repository。

构建后可将 `dist/` 中的 DMG 作为 GitHub Release 附件上传，不要提交历史安装包、`.build/` 或调试截图。首次公开前请确认是否有权分发随项目提供的角色衍生素材，并自行决定许可证。
