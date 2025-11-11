# server builder

FROM golang:1.25-alpine AS server_builder

ENV APP_HOME=/code/bbs-go/server
WORKDIR "$APP_HOME"

COPY ./server ./
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod download
RUN CGO_ENABLED=0 go build -v -o bbs-go main.go && chmod +x bbs-go


# site builder
FROM node:24-alpine AS site_builder

ENV APP_HOME=/code/bbs-go/site
WORKDIR "$APP_HOME"

COPY ./site ./
RUN npm install -g pnpm --registry=https://registry.npmmirror.com
RUN pnpm install --registry=https://registry.npmmirror.com
RUN npm install -g pnpm
RUN pnpm install
RUN pnpm build


# admin builder
FROM node:24-alpine AS admin_builder

ENV APP_HOME=/code/bbs-go/admin
WORKDIR "$APP_HOME"

COPY ./admin ./
RUN npm install -g pnpm --registry=https://registry.npmmirror.com
RUN pnpm install --registry=https://registry.npmmirror.com
RUN npm install -g pnpm
RUN pnpm install
RUN pnpm build

# run
FROM node:24-alpine

ENV APP_HOME=/app/bbs-go
WORKDIR "$APP_HOME"

COPY --from=server_builder /code/bbs-go/server/bbs-go ./server/bbs-go
COPY --from=server_builder /code/bbs-go/server/migrations ./server/migrations
COPY --from=server_builder /code/bbs-go/server/locales ./server/locales
COPY --from=site_builder /code/bbs-go/site/.output ./site/.output
COPY --from=site_builder /code/bbs-go/site/node_modules ./site/node_modules
COPY --from=admin_builder /code/bbs-go/admin/dist ./server/admin

COPY ./start.sh ${APP_HOME}/start.sh
RUN chmod +x ${APP_HOME}/start.sh

# 创建默认配置文件
RUN cat > ${APP_HOME}/server/bbs-go.yaml <<'EOF'
Language: zh-CN
Port: 8082
BaseURL: /
AllowedOrigins:
  - "*"
Installed: false
Logger:
  Filename: /tmp/bbs-go.log
  MaxSize: 100
  MaxAge: 10
  MaxBackups: 10
DB:
  Url: root:@tcp(basic-tidb.tidb-cluster.svc.cluster.local:4000)/bbsgo_db?charset=utf8mb4&parseTime=True&multiStatements=true&loc=Local&tidb_skip_isolation_level_check=1
  MaxIdleConns: 50
  MaxOpenConns: 200
Uploader:
  Enable: Local
EOF

EXPOSE 8082 3000

CMD ["./start.sh"]