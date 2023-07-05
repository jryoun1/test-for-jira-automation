#!/bin/bash

# Checkout repository
git checkout $GITHUB_SHA

# 정규식 패턴 변수 선언
regex="(T|t)(E|e)(S|s)(T|t)-[0-9]+"
branch_name=""
filtered_commits=()

extract_branch_name() {
  local input_string="$1"
  if [[ $input_string =~ $regex ]]; then
    branch_name="${BASH_REMATCH[0]}"
  fi
}

filter_commit_messages() {
  local messages="$1"
  
  while IFS= read -r line; do
    if [[ $line =~ $regex ]]; then
      local filtered_message="${BASH_REMATCH[0]}"
      echo "here $filtered_message"
      filtered_commits+=("$filtered_message")
    fi
  done <<< "$messages"
  
#  echo "${filtered[@]}"
}

# GitHub 레퍼런스에서 브랜치 정보 추출
branch_ref=$(git rev-parse --abbrev-ref HEAD)
#echo "currentBranch $branch_ref"
# 브랜치 이름 추출
extract_branch_name "$branch_ref"
echo "Extracted Branch Name: $branch_name"

# 커밋 메시지 필터링
commit_messages=$(git log --pretty=format:%s --no-merges $(git merge-base origin/main HEAD)..HEAD)
filter_commit_messages "$commit_messages"
echo "Extracted Commit Name: ${filtered_commits[@]}"

# 브랜치 이름과 필터링된 메시지 모두 비어 있는 경우
if [[ -z "$branch_name" && -z "${filtered_commits[@]}" ]]; then
  #echo "Branch name and filtered messages are empty. Skipping Jira Webhook."
  exit 0
fi

# Jira webhook URL
webhook_url="https://automation.atlassian.com/pro/hooks/ff51aba3cf64a8a40888f4cba03d1be128b8bcd6"

# Jira에 보낼 JSON 데이터 설정
payload="{\"issues\":[\"${branch_name}\""

if [[ ${#filtered_commits[@]} -gt 0 ]]; then
    payload+=","
for ((i=0; i<${#filtered_commits[@]}; i++)); do
    # 배열 요소 대문자로 변환 후 JSON 문자열에 추가
    payload+="\"$(echo "${filtered_commits[i]}" | tr '[:lower:]' '[:upper:]')\""
    # 마지막 요소가 아닌 경우 콤마 추가
    if [ $i -lt $((${#filtered_commits[@]}-1)) ]; then
      payload+=","
    fi
  done
fi

payload+="] }"
echo "$payload"

# HTTP POST 요청 보내기
curl -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url"
