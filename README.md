# ril

github上にレポジトリを作成しておく。

## Heroku上でアプリを作成する

Herokuのダッシュボードから`New`を押下し、新しいアプリを作成する。

![01](https://github.com/cipepser/ril/blob/master/img/01.png)

App Nameを決める。

![02](https://github.com/cipepser/ril/blob/master/img/02.png)

GitHubで事前に作成したレポジトリとConnectする。

![03](https://github.com/cipepser/ril/blob/master/img/03.png)

## Buffaloのプロジェクトを作成する

[Install Buffalo · Buffalo – Rapid Web Development in Go](https://gobuffalo.io/en/docs/getting-started/installation)を見て、事前に`Buffalo`をインストールしておく。

`rli`のディレクトリの一つ上で以下コマンドを実行する。

```sh
❯ buffalo new ril
```

`main.go`、`grifts/init.go`のimportパスを以下のように修正する。

```go
import (

  "github.com/cipepser/ril/actions"
)
```


## Heroku Container Registryを設定する

[Deploying Buffalo to Heroku With Docker – Buffalo — Rapid Web Development in Go](https://blog.gobuffalo.io/deploying-buffalo-to-heroku-with-docker-adafa4afdd6f)を参考に進める。

```sh
❯ heroku plugins:install heroku-container-registry
 ›   Error: heroku-container-registry is blacklisted
```

上記エラーが出てきたが、[Removing heroku\-container\-plugin instalation by paganotoni · Pull Request \#6 · markbates/buffalo\-heroku](https://github.com/markbates/buffalo-heroku/pull/6)でプラグインのインストール自体が不要になったらしい。
[Container Registry & Runtime \(Docker Deploys\) \| Heroku Dev Center](https://devcenter.heroku.com/articles/container-registry-and-runtime)の手順からも消えている。

ということで上記のステップは飛ばして先に進む。

```sh
❯ heroku container:login
Login Succeeded
```

`.dockerignore`ファイルを作成し、以下内容を記載する。

```
node_modules/
*.log
bin/
```

記事にある`Dockerfile`を使う。

```Dockerfile
# This is a multi-stage Dockerfile and requires >= Docker 17.05
# https://docs.docker.com/engine/userguide/eng-image/multistage-build/
FROM gobuffalo/buffalo:development as builder
RUN mkdir -p $GOPATH/src/path/to/app
WORKDIR $GOPATH/src/path/to/app
# this will cache the npm install step, unless package.json changes
ADD package.json .
ADD yarn.lock .
RUN yarn install --no-progress
ADD . .
RUN go get $(go list ./... | grep -v /vendor/)
RUN buffalo build --static -o /bin/app
FROM alpine
RUN apk add --no-cache bash
RUN apk add --no-cache ca-certificates
WORKDIR /bin/
COPY --from=builder /bin/app .
# Comment out to run the binary in "production" mode:
# ENV GO_ENV=production
# Bind the app to 0.0.0.0 so it can be seen from outside the container
ENV ADDR=0.0.0.0
EXPOSE 3000
# Comment out to run the migrations before running the binary:
# CMD /bin/app migrate; /bin/app
CMD exec /bin/app
```

herokuに環境情報を設定する。`-a`で設定するのは`Heroku上でアプリを作成する`で作成したアプリの名前。

```sh
❯ heroku config:set GO_ENV=production -a reminditlater
Setting GO_ENV and restarting ⬢ reminditlater... done, v3
GO_ENV: production
```

postgresを設定する。

```sh
❯ heroku addons:create heroku-postgresql:hobby-dev -a reminditlater
Creating heroku-postgresql:hobby-dev on ⬢ reminditlater... free
Database has been created and is available
 ! This database is empty. If upgrading, you can transfer
 ! data from another database with pg:copy
Created postgresql-curly-71579 as DATABASE_URL
Use heroku addons:docs heroku-postgresql to view documentation
```

configも確認できる。

```sh
❯ heroku config -a reminditlater
=== reminditlater Config Vars
DATABASE_URL: postgres://bhuxnjtwfjsphe:41ef43b30d1b43b1d2882558db3ff100724d4c0733c46e92bd909f1d0d458318@ec2-50-17-246-114.compute-1.amazonaws.com:5432/d68cu7pfm7hsdh
GO_ENV:       production
```

以下の内容で`Procfile`を作成する。

```
web: ril
```

ここでmanual deployしてもlanguage detectionに失敗する。
一旦記事と同じようにCLIでdeployする。

```sh
❯ heroku container:push web -a reminditlater
```

ちゃんと書いていないので失敗する。以下の内容に修正。

```Dockerfile
FROM gobuffalo/buffalo:latest

RUN mkdir -p $GOPATH/src/github.com/gobuffalo/ril
WORKDIR $GOPATH/src/gobuffalo/fil

ADD . .

RUN npm install
RUN buffalo build -o bin/app

CMD exec /bin/app
```

```sh
❯ heroku container:push web -a reminditlater
(中略)
Step 6/7 : RUN buffalo build -o bin/app
 ---> Running in ce717032b90e
Usage:
  buffalo build [flags]

Aliases:
  build, b, bill, install

Flags:
      --clean-assets               will delete public/assets before calling webpack
      --dry-run                    runs the build 'dry'
      --environment string         set the environment for the binary (default "development")
  -e, --extract-assets             extract the assets and put them in a distinct archive
  -h, --help                       help for build
      --ldflags string             set any ldflags to be passed to the go build
      --mod string                 -mod flag for go build
  -o, --output string              set the name of the binary
  -k, --skip-assets                skip running webpack and building assets
      --skip-template-validation   skip validating templates
  -s, --static                     build a static binary using  --ldflags '-linkmode external -extldflags "-static"'
  -t, --tags string                compile with specific build tags
  -v, --verbose                    print debugging information

time="2019-04-20T13:49:47Z" level=error msg="Error: you need to be inside your buffalo project path to run this command"
The command '/bin/sh -c buffalo build -o bin/app' returned a non-zero code: 255
 ▸    Error: docker build exited with Error: 255
```

そもそも`buffalo dev`もできない。

```sh
❯ buffalo dev
Usage:
  buffalo dev [flags]

Flags:
  -d, --debug   use delve to debug the app
  -h, --help    help for dev

ERRO[0000] Error: you need to be inside your buffalo project path to run this command
```

`GOPATH`の中で`buffalo new`しないといけないらしい。
なので、再度やり直し。

```sh
❯ buffalo new ril
(中略)
INFO[2019-04-20T22:54:50+09:00] Please read the README.md file in your new application for next steps on running your application.
```

`.dockerignore`は書いたものと同じだったので特に触らなくてよさそう。
`Dockerfile`は上記のもので置き換え。`README`も同じく置き換え。

`go.mod`は一旦使わないので`GOPATH`の中で作業を進める。

```sh
❯ heroku container:push web -a reminditlater
(中略)
Step 6/7 : RUN buffalo build -o bin/app
 ---> Running in 63b68a797320
# cd .; git clone https://github.com/cipepser/ril /go/src/github.com/cipepser/ril
Cloning into '/go/src/github.com/cipepser/ril'...
fatal: could not read Username for 'https://github.com': terminal prompts disabled
package github.com/cipepser/ril/actions: exit status 128
package github.com/cipepser/ril/models: cannot find package "github.com/cipepser/ril/models" in any of:
	/usr/local/go/src/github.com/cipepser/ril/models (from $GOROOT)
	/go/src/github.com/cipepser/ril/models (from $GOPATH)
Usage:
  buffalo build [flags]

Aliases:
  build, b, bill, install

Flags:
      --clean-assets               will delete public/assets before calling webpack
      --dry-run                    runs the build 'dry'
      --environment string         set the environment for the binary (default "development")
  -e, --extract-assets             extract the assets and put them in a distinct archive
  -h, --help                       help for build
      --ldflags string             set any ldflags to be passed to the go build
      --mod string                 -mod flag for go build
  -o, --output string              set the name of the binary
  -k, --skip-assets                skip running webpack and building assets
      --skip-template-validation   skip validating templates
  -s, --static                     build a static binary using  --ldflags '-linkmode external -extldflags "-static"'
  -t, --tags string                compile with specific build tags
  -v, --verbose                    print debugging information

time="2019-04-20T14:31:23Z" level=error msg="Error: exit status 1"
The command '/bin/sh -c buffalo build -o bin/app' returned a non-zero code: 255
 ▸    Error: docker build exited with Error: 255
```

githubにアップロードできてない。

## References
- [Deploying Buffalo to Heroku With Docker – Buffalo — Rapid Web Development in Go](https://blog.gobuffalo.io/deploying-buffalo-to-heroku-with-docker-adafa4afdd6f)
- [Install Buffalo · Buffalo – Rapid Web Development in Go](https://gobuffalo.io/en/docs/getting-started/installation)
- [Container Registry & Runtime \(Docker Deploys\) \| Heroku Dev Center](https://devcenter.heroku.com/articles/container-registry-and-runtime)
- [heroku\-container\-registry is blacklisted · Issue \#5 · markbates/buffalo\-heroku](https://github.com/markbates/buffalo-heroku/issues/5)
- [Removing heroku\-container\-plugin instalation by paganotoni · Pull Request \#6 · markbates/buffalo\-heroku](https://github.com/markbates/buffalo-heroku/pull/6)