#!/bin/bash

usage(){
    echo "Usage: $0 [option]" >&2
    echo
    echo "   -h, --help        show this help"
    echo "   -t, --title       message title"
    echo "   -d, --description message description"
    echo "   -c, --color       message color"
    echo "   -w, --webhook     discord webhook URL"
    echo
}

while getopts ":h:t:d:c:w:" opt; do
  case $opt in
    h | --help) usage; exit 0 >&2;;
    t | --title) title=$OPTARG;;
    d | --description) description=$OPTARG;;
    c | --color) color=$OPTARG;;
    w | --webhook) webhook=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done


case $color in
  "success" )
    EMBED_COLOR=3066993
    STATUS_MESSAGE="Passed"
    ;;

  "failure" )
    EMBED_COLOR=15158332
    STATUS_MESSAGE="Failed"
    ;;

  * )
    EMBED_COLOR=0
    STATUS_MESSAGE="Status Unknown"
    ;;
esac

if [ -z $webhook ]; then
  echo "webhook parameter is mandatory!" && usage && exit 1
fi

AUTHOR_NAME="$(git log -1 "$CI_COMMIT_SHA" --pretty="%aN")"
COMMITTER_NAME="$(git log -1 "$CI_COMMIT_SHA" --pretty="%cN")"
COMMIT_SUBJECT="$(git log -1 "$CI_COMMIT_SHA" --pretty="%s")"


if [ "$AUTHOR_NAME" == "$COMMITTER_NAME" ]; then
  CREDITS="$AUTHOR_NAME authored & committed"
else
  CREDITS="$AUTHOR_NAME authored & $COMMITTER_NAME committed"
fi

if [ -z $CI_MERGE_REQUEST_ID ]; then
  URL=""
else
  URL="$CI_PROJECT_URL/merge_requests/$CI_MERGE_REQUEST_ID"
fi

WEBHOOK_DATA='{
  "avatar_url": "https://gitlab.com/favicon.png",
  "embeds": [ {
    "color": '$EMBED_COLOR',
    "author": {
      "name": "Pipeline #'"$CI_PIPELINE_IID"' '"$STATUS_MESSAGE"' - '"$CI_PROJECT_PATH_SLUG"'",
      "url": "'"$CI_PIPELINE_URL"'",
      "icon_url": "https://gitlab.com/favicon.png"
    },
    "title": "'"$title"'",
    "url": "'"$URL"'",
    "description": "'"$description\\n\\n${COMMIT_SUBJECT//$'\n'/ }"\\n\\n"$CREDITS"'",
    "fields": [
      {
        "name": "Commit",
        "value": "'"[\`$CI_COMMIT_SHORT_SHA\`]($CI_PROJECT_URL/commit/$CI_COMMIT_SHA)"'",
        "inline": true
      },
      {
        "name": "Branch",
        "value": "'"[\`$CI_COMMIT_REF_NAME\`]($CI_PROJECT_URL/tree/$CI_COMMIT_REF_NAME)"'",
        "inline": true
      }
    ]
  } ]
}'


echo -e "[Webhook]: Sending webhook to Discord...\\n";

(curl --fail --progress-bar -A "GitLabCI-Webhook" -H Content-Type:application/json -d "$WEBHOOK_DATA" "$webhook" \
&& echo -e "\\n[Webhook]: Successfully sent the webhook.") || echo -e "\\n[Webhook]: Unable to send webhook."
