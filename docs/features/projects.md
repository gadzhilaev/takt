# Проекты

- Создание проекта текущим пользователем → он `ProjectMemberRole.admin`  
- Цвет, иконка, описание; архивация  
- Членство: admin / member / viewer  
- Новые проекты получают 4 столбца: К выполнению / В работе / На проверке / Готово  
- `is_demo=true` — видимость только для участников (даже системный admin без membership не видит)  
- Leave requests: участник может запросить выход (`010_project_leave_requests`)

API: `/api/v1/projects`. Web: `/app/projects`, редирект на последний проект. Mobile: hub + board.
