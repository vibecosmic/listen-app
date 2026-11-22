# 第三方许可清单

本仓库的 MIT 许可证（见 [LICENSE](LICENSE)）仅适用于本仓库的原创代码和文档。
第三方依赖与随仓库分发的资产（示例音频、字幕、字体、词典等）各自适用其原许可证，不被 MIT 覆盖。

## 直接依赖

| 名称 | 许可证 | 来源链接 |
| --- | --- | --- |
| `just_audio` | MIT | https://pub.dev/packages/just_audio |
| `material_ui` | BSD-3-Clause | https://pub.dev/packages/material_ui |

## 随仓库分发的资产

授权不明的音频、字幕、字体、词典等资产不得放入本仓库。以下为本仓库自制的示例资产（随原创内容采用 MIT 许可证）：

| 资产 | 许可证 | 来源链接 |
| --- | --- | --- |
| `assets/sample_en.m4a` | MIT（本仓库自制合成音频） | 仓库内自制 |
| `assets/sample_ja.m4a` | MIT（本仓库自制合成音频） | 仓库内自制 |
| `assets/sentences_en.json` | MIT（本仓库自制示例字幕） | 仓库内自制 |
| `assets/sentences_ja.json` | MIT（本仓库自制示例字幕） | 仓库内自制 |

## 更新方式

- Flutter 工程（`pubspec.yaml` / `pubspec.lock`）出现后，在同一个 PR 中把每个直接依赖的名称、许可证和 pub.dev 来源链接加入上表；许可证以依赖包自身声明为准。
- 每次新增、升级或移除依赖或资产时同步更新本文件。
- 若发现某依赖或资产的许可证与 MIT 分发冲突，不要合并，记录在 Issue 中并交给 Director。
