# Build Tools for Visual Studio

## ダウンロード

インストールパッケージをダウンロードする。

```sh
vs_BuildTools.exe ^
    --layout <Path\\To\\Download> ^
    --lang ja-JP ^
    --includeRecommended ^
    --add Microsoft.VisualStudio.Workload.VCTools
```

ダウンロードするコンポーネントは [Visual Studio Build Tools コンポーネント ディレクトリ](https://learn.microsoft.com/ja-jp/visualstudio/install/workload-component-id-vs-build-tools?view=visualstudio) を参照する。

## インストール

インストーラを起動する。

```sh
vs_BuildTools.exe
```

インストーラが起動せず *%LocalAppData%\\temp\\dd_vs_BuildTools_decompression_log.txt* に下記のログが出力される場合は
[Microsoft Windows Code Signing PCA 2024 証明書](https://www.microsoft.com/pkiops/certs/Microsoft%20Windows%20Code%20Signing%20PCA%202024.crt)
が必要になる。

```text
Launched extracted application exiting with result code: 0x138b
```
