from fastapi import APIRouter

from app.api.v1 import admin, auth, files, invites, notifications, projects, reports, settings, tasks, users

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(admin.router)
api_router.include_router(users.router)
api_router.include_router(settings.router)
api_router.include_router(projects.router)
api_router.include_router(invites.router)
api_router.include_router(tasks.router)
api_router.include_router(reports.router)
api_router.include_router(files.router)
api_router.include_router(notifications.router)
