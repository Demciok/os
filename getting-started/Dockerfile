# syntax=docker/dockerfile:1
FROM python:3.12-alpine  # Builds an image with the Python 3.12 image
WORKDIR /code  # Sets the working directory to `/code`
ENV FLASK_APP=app.py  # Sets environment variables used by the `flask` command
ENV FLASK_RUN_HOST=0.0.0.0
RUN apk add --no-cache gcc musl-dev linux-headers  # Installs `gcc` and other dependencies
COPY requirements.txt .  # Copies `requirements.txt`
RUN pip install -r requirements.txt  # Installs the Python dependencies
COPY . .  # Copies the current directory `.` in the project to the workdir `.` in the image
EXPOSE 5000
CMD ["flask", "run", "--debug"]  # Sets the default command for the container to `flask run --debug`