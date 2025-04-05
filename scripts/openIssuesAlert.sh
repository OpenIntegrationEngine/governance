#!/bin/bash

dayago1=$(date --date '1 day ago' +%s)
dayago2=$(date --date '2 days ago' +%s)

function render() {
  echo "## Issues with activity $2 ago" > "$1.md"
  echo >> "$1.md"
  jq -r '.[] | "- [**#\(.number) \(.title)**](\(.url))"' "$1.json" >>  "$1.md"
}

# Get all issues
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/openintegrationengine/governance/issues?state=open \
  | jq -r '[.[] | {url: .html_url, title: .title, updated_at: .updated_at, number: .number}]' \
  > issues.json

# Get issues with latest activity in the past 24 hours
jq --argjson dayago1 "$dayago1" '
  map( select(
    (.updated_at | fromdateiso8601) >= $dayago1
  ))
' issues.json  > 0dayold.json

# Get issues with latest activity between 24 and 48 hours ago
jq --argjson dayago1 "$dayago1" \
   --argjson dayago2 "$dayago2" '
  map( select(
    (.updated_at | fromdateiso8601) < $dayago1 and
    (.updated_at | fromdateiso8601) >= $dayago2
  ))
' issues.json  > 1dayold.json

# Get issues with latest activity more than 48 hours ago
jq --argjson dayago2 "$dayago2" '
  map( select(
    (.updated_at | fromdateiso8601) < $dayago2
  ))
' issues.json  > 2dayold.json


################################

# Render message bodies

################################
render "0dayold" "less than a day"
render "1dayold" "less than two days"
render "2dayold" "more than two days"

jq -n --rawfile dataday0 0dayold.md \
   -n --rawfile dataday1 1dayold.md \
   -n --rawfile dataday2 2dayold.md '
{
  embeds: [
    {
        description: "# Currently open Governance issues",
    },
    {
      description: $dataday0,
      color: 5763719
    },
    {
      description: $dataday1,
      color: 15105570
    },
    {
      description: $dataday2,
      color: 15548997,
    }
  ]
}
' > curlBody.json

curl -X POST --location "$DISCORD_HOOK" \
    -H "Content-Type: application/json" \
    -d @curlBody.json
