FROM gobuffalo/buffalo:latest

RUN mkdir -p $GOPATH/src/github.com/gobuffalo/ril
WORKDIR $GOPATH/src/gobuffalo/fil

ADD . .

RUN npm install
RUN buffalo build -o bin/app

CMD exec bin/app