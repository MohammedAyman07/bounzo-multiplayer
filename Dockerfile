FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    libfontconfig1 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download Godot 4.7.1 Linux headless runner
RUN wget -q https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip -O godot.zip \
    && unzip godot.zip \
    && mv Godot_v4.7.1-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm godot.zip

# Copy game files
COPY . /app

# Expose default UDP port
EXPOSE 7777/udp

# Run dedicated authoritative multiplayer server
CMD ["godot", "--headless", "--scene", "res://scenes/multiplayer/server_main.tscn", "--", "--port", "7777"]
