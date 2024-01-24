#!/bin/bash
#
# Performance Co-Pilot を使用してプロセスのメトリクスを取得する。
#
# 必要なパッケージ:
# - pcp-system-tools
# - pcp-doc
# - pcp-gui
#
# 事前準備
# - pmcd サービスを起動しておく

set -e

if [[ -z $1 || -z $2 ]]; then
    {
        echo "Usage:"
        echo " $0 <ProcessID> <Interval[s]>"

    } >&2

    exit 1
fi

if ps x | awk '{ print $1 }' | grep -q "^$1$"; then
    :
else
    echo "Not found ProcessID $1" >&2
    exit 1
fi


# 文字列型以外のメトリクスを取得する。
metrics=($(pminfo -d proc | awk -v RS='' -v FS='\n' '$2 !~ /Data Type: string/ { print $1 }' | sed -e "s/$/[$1]/"))

# プロセス単位ではないメトリクスを取得する。
metrics_indom_null=$(pminfo proc -d | awk -v RS='' -v FS='\n' '$2 ~ /InDom: PM_INDOM_NULL/ { print $1 }')

# プロセス単位ではないメトリクスからプロセスIDを削除する。
for m in ${metrics_indom_null}
do
    metrics=($(echo ${metrics[@]} | xargs -n 1 echo | sed -e "s/\($m\).*/\1/"))
done

# 取得を開始する。
pmdumptext -t ${2}sec -d , -f '%Y/%m/%d %H:%M:%S' -MuN -c <(echo ${metrics[*]} | xargs -n 1 echo)
