module.exports =

  production:
    port: process.env.PORT || 3002
    allow_origins: "*.vidigami.com"

  staging:
    port: process.env.PORT || 3002
    allow_origins: "*.vidigami.com"

  review:
    port: process.env.PORT || 3002
    allow_origins: '*'

  development:
    port: process.env.PORT || 5001
    allow_origins: '*'

  test:
    port: process.env.PORT || 5001
    allow_origins: '*'
