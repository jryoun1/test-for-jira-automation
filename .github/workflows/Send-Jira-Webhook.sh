#!/bin/bash

# Checkout repository
git checkout $GITHUB_SHA

# 정규식 패턴 변수 선언
regex="(T|t)(E|e)(S|s)(T|t)-[0-9]+"

extract_branch_name() {
  local input_string="$1"
  if [[ $input_string =~ $regex ]]; then
    local branch_name="${BASH_REMATCH[0]}"
    echo "$branch_name"
  fi
}

filter_commit_messages() {
  local messages="$1"
  local filtered=()
  
  while IFS= read -r line; do
    if [[ $line =~ $regex ]]; then
      local filtered_message="${BASH_REMATCH[0]}"
      filtered+=("$filtered_message")
    fi
  done <<< "$messages"
  
  echo "${filtered[@]}"
}

# GitHub 레퍼런스에서 브랜치 정보 추출
branch_ref="${{ github.ref }}"
# 브랜치 이름 추출
branch_name=$(extract_branch_name "$branch_ref")
echo "Extracted Branch Name: $branch_name"

# 커밋 메시지 필터링
commit_messages=$(git log --pretty=format:%s --no-merges $(git merge-base jeongmin/main HEAD)..HEAD)
echo "commit_messages: $commit_messages"
filtered_commits=$(filter_commit_messages "$commit_messages")

# 필터링된 커밋 메시지에서 정규식에 해당하는 부분 추출하여 String 배열로 만들기
filtered_messages=()
for commit in "${filtered_commits[@]}"; do
  filtered_messages+=("$commit")
done

# 필터링된 커밋 메시지 출력
echo "Filtered Commits:"
for message in "${filtered_messages[@]}"; do
  echo "- $message"
done

# 브랜치 이름과 필터링된 메시지 모두 비어 있는 경우
if [[ -z "$branch_name" && -z "${filtered_messages[@]}" ]]; then
  echo "Branch name and filtered messages are empty. Skipping Jira Webhook."
  exit 0
fi

# Jira webhook URL
webhook_url="https://automation.atlassian.com/pro/hooks/ff51aba3cf64a8a40888f4cba03d1be128b8bcd6"

# Jira에 보낼 JSON 데이터 설정
payload="{\"issues\":[\"${branch_name^^}\"]"

if [[ ${#filtered_messages[@]} -gt 0 ]]; then
  for message in "${filtered_messages[@]}"; do
    payload+=",\"${message^^}\""
  done
fi

payload+="}"

# HTTP POST 요청 보내기
curl -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url"
