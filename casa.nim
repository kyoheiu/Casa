import markdown, unicode, json, os, tables, strutils, algorithm

include "templates/page_base.nimf"
include "templates/index_base.nimf"

type
  PageConfig = object
    date: string
    title: string
    name: string

var
  pages = newSeq[PageConfig]()
  countChange = 0

var
  page_date, page_title, page_content: string
  page_categories, page_tags: seq[JsonNode]
  config_title, base_url: string
  file_name: string

const
  configTemplate = """
base_url = "https://example.com"
title = "site title"
"""

proc build() =
  removeDir("public")
  createDir("public")
  let config = parseFile("config.json")
  config_title = config["title"].getStr("notitle")
  base_url = config["base_url"].getStr("nourl")
  for cssFile in walkFiles("css/*.css"):
    copyFileToDIr(cssfile, "public")
  for contentFileDir in walkDirs("content/*"):
    file_name = splitPath(contentFileDir).tail
    let
      mdFile = readFile(contentFileDir & "/" & file_name & ".md")
    page_content = markdown(mdFile)
    let frontMatter = parseFile(contentFileDir & "/" & file_name & ".json")
    page_title = frontMatter["title"].getStr()
    page_date = frontMatter["date"].getStr()
    page_categories = frontMatter["categories"].getElems()
    page_tags = frontMatter["categories"].getElems()
    pages.add(PageConfig(date: page_date, title: page_title, name: file_name))
    let
      publicDirPath  = "public/content/" & file_name
      publicFilePath = publicDirPath & "/index.html"
      pageHtml   = generatePageHtml(config_title, base_url, page_date, page_title, page_content, page_categories, page_tags)
    createDir(publicDirPath)
    writeFile(publicFilePath, pageHtml)
    inc(countChange)
  let
    sortedPages = pages.sortedByIt(it.date).reversed
    indexHtml = generateIndexHtml(config_title, base_url, sortedPages)
  writeFile("public/index.html", indexHtml)
  echo $countChange & " page(s) created."

proc init(siteName: string) =
  createDir siteName
  createDir siteName & "/content"
  createDir siteName & "/templates"
  createDir siteName & "/static"
  writeFile(siteName & "/config.toml", configTemplate)

when isMainModule:
  import cligen
  dispatchMulti([build], [init])