#!/bin/bash
set -e

cd $(dirname $0)

jekyll build
cd _site
rm publish.sh
rm -rf .git
git init

git remote add origin https://hoozecn:$CI_TOKEN@github.com/hoozecn/hoozecn.github.io
git add -A
git ci -am 'update'
git push origin -f master:gh-pages
cd ..
jekyll clean