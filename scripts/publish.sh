#!/bin/bash

# 自动生成版本号：1.0.YYYYMMDD[-N]
today=$(date +%Y%m%d)
today_prefix="1.0.${today}"

# 读取当前版本号
current_version=$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' cjpm.toml)

# 判断当日是否已发布过
if echo "$current_version" | grep -q "^${today_prefix}"; then
    # 提取后缀次数
    suffix=${current_version#${today_prefix}}
    if [ -z "$suffix" ]; then
        count=2
        new_version="${today_prefix}-${count}"
    else
        count=$(( ${suffix#*-} + 1 ))
        new_version="${today_prefix}-${count}"
    fi
else
    new_version="${today_prefix}"
fi

# 更新 cjpm.toml 中的版本号
sed -i '' "s/^\([[:space:]]*version[[:space:]]*=[[:space:]]*\)\"[^\"]*\"/\\1\"${new_version}\"/" cjpm.toml

echo "版本号: ${new_version}"

cjpm build
cjpm bundle --skip-test --skip-lint
cjpm publish