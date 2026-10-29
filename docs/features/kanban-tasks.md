# Задачи и Kanban

- Столбец = `TaskStatus` (`is_done`, цвет, порядок)  
- Задача: title, description, priority, assignees 0..n, labels, due date, checklist, comments  
- Создание: `position = min(column) − 1024` (всегда в начало)  
- Перемещение: `POST /tasks/{id}/move`  
- Удаление: soft-delete; **только автор** (`can_delete_task`)  
- Web: `KanbanBoard` + task drawer (`?task=`)  
- Mobile: board page + task form/detail  

Отчёты Excel доступны через API `/reports`; отдельный web dashboard с графиками в продуктовый UI **не** входит (упрощённый Kanban).
