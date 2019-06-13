#!/bin/bash
set -e

cd $(dirname $0)

if [ -f token ]; then
    export CI_TOKEN=$(cat token)
fi

rm -rf _site && mkdir -p _site

pushd _site
  rm -rf .git
  git init
  
  git remote add origin https://hoozecn:$CI_TOKEN@github.com/hoozecn/hoozecn.github.io
  git fetch origin --depth=10
  git co origin/master -b master

  pushd ..
    jekyll build
  popd
  rm -f token
  rm -f publish.sh

  git add -A
  git commit -am 'update'
  git push origin master:master
  (cd .. && jekyll clean)
popd