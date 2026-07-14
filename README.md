# weather-api

Small Zig web server demo.

It calls Open-Meteo and returns weather JSON. No weather API key is required.

## Run

```sh
zig build run
```

Server:

```txt
http://localhost:3000
```

## Check Build

```sh
zig build check
```

## Endpoints

```txt
GET  /app/healthz
GET  /app/doc
GET  /api/v1/weather
GET  /api/v1/weather?lat=13.7563&lon=100.5018
POST /api/users
POST /api/login
```

## Weather

Default location is Phnom Penh.

```sh
curl "http://localhost:3000/api/v1/weather"
```

Custom coordinates:

```sh
curl "http://localhost:3000/api/v1/weather?lat=13.7563&lon=100.5018"
```

## Users

These endpoints use Postgres.

`src/.env` needs:

```env
DB="postgresql://user@localhost:5432/dbname"
ROLE="admin"
```

Create user:

```sh
curl -X POST "http://localhost:3000/api/users" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret"}'
```

Login:

```sh
curl -X POST "http://localhost:3000/api/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret"}'
```

## Notes

- Weather data comes from `api.open-meteo.com`.
- Weather route does not use `.env`.
- User and login routes need Postgres and `libpq`.
