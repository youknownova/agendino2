import logging
import os

import sentry_sdk
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.auth_middleware import AuthMiddleware
from app.depends import get_auth_service, is_auth_enabled
from app.router import router

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")

if os.environ.get("SENTRY_DSN"):
    sentry_sdk.init(dsn=os.environ["SENTRY_DSN"], traces_sample_rate=0.1)

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

if is_auth_enabled():
    app.add_middleware(AuthMiddleware, auth_service=get_auth_service())

app.include_router(router)
