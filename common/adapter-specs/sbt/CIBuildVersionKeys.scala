/*
 * Copyright (c) 2024–2026 Tomshley
 *
 * Licensed under the Apache License, Version 2.0
 */

package com.tomshley.cicd.adapter.sbt

import sbt.*

/**
 * Canonical reference implementation for CI/CD version composition in SBT.
 * 
 * This trait defines the standard version composition logic that combines
 * a base version from the VERSION file with a CI build revision identifier.
 * 
 * Contract:
 * - Read base version from magicRootBaseVersion setting (from VERSION file)
 * - Read TOMSHLEY_CICD_BUILD_REVISION from environment
 * - If revision is non-empty, append with hyphen separator
 * - If revision is empty, use base version as-is
 * 
 * @see https://gitlab.com/tomshley/tomshley-oss-dependencies/-/tree/main/cicd-pipelines/common/adapter-specs/
 */
protected[sbt] trait CIBuildVersionKeys {
  
  /**
   * Standard CI/CD version composition settings.
   * 
   * Example outputs:
   * - VERSION="1.2.3", TOMSHLEY_CICD_BUILD_REVISION="" → "1.2.3"
   * - VERSION="1.2.3", TOMSHLEY_CICD_BUILD_REVISION="develop-abc1234" → "1.2.3-develop-abc1234"
   */
  lazy val cicdBuildVersionSettings: Seq[Def.Setting[String]] = Seq(
    version := {
      val base = magicRootBaseVersion.value
      val revision = sys.env.getOrElse("TOMSHLEY_CICD_BUILD_REVISION", "")
      if (revision.nonEmpty) s"$base-$revision" else base
    }
  )
  
  /**
   * Base version setting key.
   * Consumers must provide this setting (typically from VersionFilePlugin).
   */
  val magicRootBaseVersion: SettingKey[String] = settingKey[String]("Base version from VERSION file")
}
