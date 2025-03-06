{
  specVersion: "2",
  local jekyll_common(docs_version, graalvm_version) = {
    capabilities: ["linux", "amd64"],
    # Necessary to use the precompiled nokogiri
    docker: {
      image: "phx.ocir.io/oraclelabs2/c_graal/buildslave:buildslave_ol7",
      mount_modules: true,
    },
    packages: {
      ruby: "==2.6.6",
      libffi: ">=3.2.1",
      nodejs: ">=8.9.4",
      git: ">=2.9.3",
    },
    downloads: {
      LIBGMP: {name: "libgmp", version: "6.1.0", platformspecific: true}
    },
    environment: {
      JEKYLL_ENV: "production",
      BUNDLE_PATH: "$PWD/../bundle-path",
      CPPFLAGS: "-I$LIBGMP/include",
      LD_LIBRARY_PATH: "$LIBGMP/lib:$LD_LIBRARY_PATH",
      LIBRARY_PATH: "$LIBGMP/lib:$LIBRARY_PATH",
      CI: "true",
      DOCS_VERSION: docs_version,
      GRAALVM_VERSION: graalvm_version,
    },
    timelimit: "20:00",
    setup: [
      ["mkdir", "../gem-home"],
      ["export", "GEM_HOME=$PWD/../gem-home"],
      ["gem", "install", "--no-document", "bundler", "-v", "2.1.4"],
      ["export", "PATH=$GEM_HOME/bin:$PATH"],
      ["bundle", "install"],
    ],
  },

  local jekyll_build(docs_version, graalvm_version) = jekyll_common(docs_version, graalvm_version) + {
    run: [
      ["gem", "install", "nokogiri", "-v", "1.13.10"],
      ["./_scripts/build.sh"],
      ["head", docs_version + "/index.html"],
      ["echo", "Checking that top-level directory has no unexpected entries"],
      ["ls", "-1", docs_version, "|", "sort", ">", "_actual-sorted-output.txt"],
      ["sort", "_scripts/expected-output.txt", ">", "_expected-sorted-output.txt"],
      ["diff", "_actual-sorted-output.txt", "_expected-sorted-output.txt", "||", "exit", "23"],
    ],
    publishArtifacts: [
      {
        name: "jekyll_build_artifact_" + docs_version,
        dir: docs_version,
        patterns: ["*"],
      }
    ]
  },

  local publish_staging(docs_version, graalvm_version) = {
    capabilities: ["linux", "amd64"],
    requireArtifacts: [
      {
        name: "jekyll_build_artifact_" + docs_version,
        dir: docs_version,
      }
    ],
    run: [
      ["rsync", "-rlv", "-e", "ssh -p 2224 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no", "--exclude-from", "_rsync-excluded", docs_version + "/", "graal@ol-graal-infra4.oraclecorp.com:/var/www/html/" + docs_version]
    ]
  },

  local publish_github(docs_version, graalvm_version) = {
    capabilities: ["linux", "amd64"],
    requireArtifacts: [
      {
        name: "jekyll_build_artifact_" + docs_version,
        dir: docs_version,
      }
    ],
    run: [
      ["git", "clone", "ssh://git@ol-bitbucket.us.oracle.com:7999/g/graalvm-website.git"],
      ["rsync", "-a", "--delete", "--exclude-from", "_rsync-excluded", "--filter", "P /*/javadoc/", docs_version + "/", "graalvm-website/" + docs_version],
      ["git", "-C", "graalvm-website", "add", "."],
      ["git", "-C", "graalvm-website", "status"],
      ["git", "-C", "graalvm-website", "-c", "user.name=Web Publisher", "-c", "user.email=graalvm-dev@oss.oracle.com", "commit", "-m", "Update website"],
      ["git", "-C", "graalvm-website", "push", "origin", "HEAD"],
      ["git", "branch", "--force", "--no-track", "published"],
      ["git", "push", "--force", "origin", "published"],
    ]
  },

  builds: std.flattenArrays([[
    jekyll_build(versions[0], versions[1]) + {name: "jekyll-build-"+versions[0], targets: ["gate"]},
    publish_staging(versions[0], versions[1]) + {name: "deploy-staging-"+versions[0], targets: ["deploy"] }, # execute manually
    publish_github(versions[0], versions[1])  + {name: "deploy-production-"+versions[0], targets: ["deploy"]}, # execute manually
  ] for versions in [
    ["21.3", "21.3"],
    ["22.0", "22.0"],
    ["22.1", "22.1"],
    ["22.2", "22.2"],
    ["22.3", "22.3"],
    ["jdk20", "23.0"],
    ["jdk22", "24.0"],
    ["jdk24", "24.2"],
  ]])
}