# Site samples

SVGs the website shows being optimized (landing, playground). They are kept as they were
downloaded: the point is to optimize them as they arrive. The logos are trademarks of their
owners, shown only as optimization samples; no affiliation or endorsement is implied.

| file | what | source | licence |
| --- | --- | --- | --- |
| `nib.svg` | Nib, the svgo.mbt mascot | drawn for this project; this copy carries editor-style metadata, ids and six-decimal numbers so the optimizer has something to remove | MIT, as the repository |
| `deepseek.svg` | DeepSeek logo | `images/logo.svg` in https://github.com/deepseek-ai/DeepSeek-VL | MIT (repository licence); trademark of DeepSeek |
| `qwen.svg` | Qwen logo | https://commons.wikimedia.org/wiki/File:Qwen_Logo.svg | Apache-2.0 per Commons; trademark of Alibaba Cloud |
| `mistral.svg` | Mistral AI logo | https://commons.wikimedia.org/wiki/File:Mistral_AI_logo_(2025–).svg | public domain per Commons; trademark of Mistral AI |

`node packages/compare/render-diff.mjs app/website/samples --exact` must report 0 differing
pixels for every file here (CI and `scripts/verify.sh --full` run it); the landing page states it.
