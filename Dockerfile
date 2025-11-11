# server builder

FROM golang:1.25-alpine AS server_builder

ENV APP_HOME=/code/bbs-go/server
WORKDIR "$APP_HOME"

COPY ./server ./
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod tidy
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
language: zh-CN
baseURL: /
port: 8082
ipDataPath: ""
allowedOrigins:
- '*'
installed: true
logger:
  filename: /tmp/bbs-go.log
  maxSize: 100
  maxAge: 10
  maxBackups: 10
db:
  url: root:123456sS#@tcp(basic-tidb.tidb-cluster.svc.cluster.local:4000)/bbsgo_db?charset=utf8mb4&parseTime=True&multiStatements=true&loc=Local&tidb_skip_isolation_level_check=1
  maxIdleConns: 50
  maxOpenConns: 200
  connMaxIdleTimeSeconds: 0
  connMaxLifetimeSeconds: 0
smtp:
  host: ""
  port: ""
  username: ""
  password: ""
  ssl: false
search:
  indexPath: ""
baiduSEO:
  site: ""
  token: ""
smSEO:
  site: ""
  userName: ""
  token: ""
EOF

EXPOSE 8082 3000

CMD ["./start.sh"]