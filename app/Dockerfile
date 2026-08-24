FROM nginx:alpine

# Static site + server config listening on port 5000
COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:5000/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
