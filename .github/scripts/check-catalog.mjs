#!/usr/bin/env node
// 校验范围：根 package.json + apps/* 与 packages/* 的 package.json
// 根依赖（lefthook / prettier 等工具）同样受 catalog: 单一真源约束
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const ROOTS = ['apps', 'packages']
const FIELDS = ['dependencies', 'devDependencies', 'optionalDependencies']
const ALLOWED = /^(catalog:|workspace:)/

const errors = []

function checkPackage(file) {
  let pkg
  try {
    pkg = JSON.parse(readFileSync(file, 'utf8'))
  } catch (error) {
    errors.push(`${file}: 无法解析 package.json（${error.message}）`)
    return
  }

  for (const field of FIELDS) {
    const dependencies = pkg[field]
    if (dependencies === undefined) continue
    if (dependencies === null || typeof dependencies !== 'object') {
      errors.push(`${file}: ${field} 必须是对象`)
      continue
    }

    for (const [name, spec] of Object.entries(dependencies)) {
      if (typeof spec !== 'string' || !ALLOWED.test(spec)) {
        errors.push(
          `${file}: ${field}.${name} = ${JSON.stringify(spec)}，应使用 catalog: 或 workspace:`,
        )
      }
    }
  }
}

for (const root of ROOTS) {
  if (!existsSync(root)) continue
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue
    const file = join(root, entry.name, 'package.json')
    if (existsSync(file)) checkPackage(file)
  }
}

if (existsSync('package.json')) checkPackage('package.json')

if (errors.length > 0) {
  for (const error of errors) console.error(`::error::${error}`)
  process.exit(1)
}

console.log('catalog 校验通过：根 package.json 与 apps / packages 的直接依赖均使用 catalog: 或 workspace:')
