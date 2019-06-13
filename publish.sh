#!/bin/bash
set -e

cd $(dirname $0)

if [ -f token ]; then
    export CI_TOKEN=$(cat token)
fi

jekyll build
cd _site
rm -f token
rm -f publish.sh
rm -rf .git
git init

git remote add origin https://hoozecn:$CI_TOKEN@github.com/hoozecn/hoozecn.github.io
git add -A
git commit -am 'update'
git push origin -f master:master
cd ..
jekyll clean
