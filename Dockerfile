#-----------------------------------------------------------------------------
# Variables shared across multiple stages
ARG KOBWEB_APP_ROOT="site"
# Define versions centrally
ARG JAVA_VERSION=17
ARG NODE_MAJOR_VERSION=20
ARG KOBWEB_CLI_VERSION=0.9.18

#-----------------------------------------------------------------------------
# Build Stage: Build and export the Kobweb site
FROM openjdk:${JAVA_VERSION}-jdk as export

ARG KOBWEB_APP_ROOT
ARG KOBWEB_CLI_VERSION
ARG NODE_MAJOR_VERSION

ENV KOBWEB_CLI_VERSION=${KOBWEB_CLI_VERSION}

# Install necessary OS packages, Node.js (LTS), and potentially Playwright
# Combine steps and add cleanup to reduce layer size.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl gnupg unzip wget ca-certificates \
    # Install Node.js (Current LTS)
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    # --- Optional: Playwright Installation ---
    # If you NEED Playwright for your build (e.g., JS pre-rendering):
    # 1. Keep nodejs install above.
    # 2. Uncomment the following lines:
    # && npm install -g npm@latest \ # Good practice to update npm
    # && npx playwright install --with-deps chromium \
    # --- End Optional Playwright ---
    # Cleanup APT cache
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Fetch the specified version of the Kobweb CLI
RUN wget "https://github.com/varabyte/kobweb-cli/releases/download/v${KOBWEB_CLI_VERSION}/kobweb-${KOBWEB_CLI_VERSION}.zip" \
    && unzip "kobweb-${KOBWEB_CLI_VERSION}.zip" \
    && rm "kobweb-${KOBWEB_CLI_VERSION}.zip"

# Add Kobweb CLI to PATH
ENV PATH="/kobweb-${KOBWEB_CLI_VERSION}/bin:${PATH}"

# Copy project code
COPY . /project

# Set workdir AFTER copying project
WORKDIR /project/${KOBWEB_APP_ROOT}

# Configure Gradle memory (optional, adjust as needed)
# Consider externalizing or caching the ~/.gradle directory for faster builds
RUN mkdir -p ~/.gradle && \
    echo "org.gradle.jvmargs=-Xmx256m" >> ~/.gradle/gradle.properties

# Build and export the site
# Consider caching Gradle dependencies before this step for faster rebuilds
# e.g., COPY build.gradle.kts gradlew ./
#       RUN ./gradlew dependencies
#       COPY . .
RUN kobweb export --notty

#-----------------------------------------------------------------------------
# Final Stage: Run the Kobweb server
FROM openjdk:${JAVA_VERSION}-jre-slim as run

ARG KOBWEB_APP_ROOT

# Copy only the necessary exported artifacts from the build stage
COPY --from=export /project/${KOBWEB_APP_ROOT}/.kobweb /.kobweb

# Expose the default Kobweb port (adjust if needed)
EXPOSE 8080

# Set the entrypoint to start the server
ENTRYPOINT [".kobweb/server/start.sh"]

# Optional: Add a healthcheck if your server supports it
# HEALTHCHECK --interval=15s --timeout=3s --start-period=30s \
#   CMD curl --fail http://localhost:8080 || exit 1