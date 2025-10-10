/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.spark.sql.avro

import org.apache.gluten.execution.{BatchScanExecTransformer, FileSourceScanExecTransformer}

import org.apache.spark.sql.GlutenSQLTestsBaseTrait
import org.apache.spark.sql.avro.GlutenAvroTestBase._
import org.apache.spark.sql.execution.FileSourceScanExec
import org.apache.spark.sql.execution.datasources.v2.BatchScanExec

import java.io.File
import java.nio.file.{Files, Path, StandardCopyOption}
import scala.collection.mutable
import scala.util.Using

/**
 * Gluten wrapper suites for Spark Avro module unit tests.
 *
 * These suites extend the corresponding Spark Avro test suites to make sure the
 * Gluten plugin is enabled and the same coverage is executed against the
 * columnar backend.
 */
class GlutenAvroSuite extends AvroSuite with GlutenSQLTestsBaseTrait {

  test("native") {
    val df = spark.read.format("avro").load("file:///tmp/gluten-avro-resources14680778583777658194/episodes.avro")
//    val executedPlans = getExecutedPlan(df)
    df.show
    df.count()
  }

  test("native avro scan") {
    withTempPath { tempDir =>
      val avroDir = new File(tempDir, "data").getCanonicalPath
      spark.range(4).write.format("avro").save(avroDir)

      val df = spark.read.format("avro").load(avroDir)
      val executedPlans = getExecutedPlan(df)

      val hasNativeScan = executedPlans.exists {
        case _: FileSourceScanExecTransformer => true
        case _: BatchScanExecTransformer => true
        case _ => false
      }
      assert(hasNativeScan, s"Expected native scan, but got plan: ${df.queryExecution.executedPlan}")

      val hasFallbackScan = executedPlans.exists {
        case _: FileSourceScanExec => true
        case _: BatchScanExec => true
        case _ => false
      }
      assert(!hasFallbackScan, s"Unexpected fallback plan: ${df.queryExecution.executedPlan}")
    }
  }
}

class GlutenAvroV1Suite extends AvroV1Suite with GlutenAvroTestBase

//class GlutenAvroV2Suite extends AvroV2Suite with GlutenAvroTestBase

trait GlutenAvroTestBase extends GlutenSQLTestsBaseTrait {
  override protected def testFile(testResource: String): String = {
    extractedResources.getOrElseUpdate(testResource, copyToDisk(testResource))
  }
}

object GlutenAvroTestBase {
  private val extractedResources = mutable.Map.empty[String, String]
  private val tempDir: Path = {
    val dir = Files.createTempDirectory("gluten-avro-resources")
//    dir.toFile.deleteOnExit()
    dir
  }

  private def copyToDisk(resource: String): String = {
    require(resource.nonEmpty, "Resource name cannot be empty")
    val stream = Option(Thread.currentThread().getContextClassLoader.getResourceAsStream(resource))
      .orElse(Option(getClass.getClassLoader.getResourceAsStream(resource)))
      .getOrElse(throw new IllegalArgumentException(s"Resource $resource not found on classpath"))

    val target = tempDir.resolve(resource)
    val parent = target.getParent
    if (parent != null) {
      Files.createDirectories(parent)
    }

    Using.resource(stream) { inputStream =>
      Files.copy(inputStream, target, StandardCopyOption.REPLACE_EXISTING)
    }

//    target.toFile.deleteOnExit()
    target.toFile.getCanonicalPath
  }
}

