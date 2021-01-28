import markdown, unicode, parsetoml, os, tables, strutils, algorithm

include "templates/page_base.nimf"
include "templates/index_base.nimf"

proc extractOnlyName(path: string): string =
  let (dir, name, ext) = splitFile(path)
  return name

type
  PageConfig = object
    date: string
    title: string
    name: string

var pages = newSeq[PageConfig]()

var
  page_title, page_content: string
  page_date, page_date_fmt: string
  page_categories, page_tags: seq[TomlValueRef]
  countChange = 0

var
  file_name: string
  config_title, base_url: string

const
  configTemplate = """
base_url = "https://example.com"
title = "site title"
"""
  publicIndex = "public/index.html"

proc build() =
  removeDir("public")
  createDir("public")
  let config = parsetoml.parseFile("config.toml")
  config_title = config["title"].getStr()
  base_url = config["base_url"].getStr()
  for kind, path in walkDir("css"):
    copyFileToDIr(path, "public")
  for kind, path in walkDir("content"):
    file_name = extractOnlyName(path)
    let
      mdFile = readFile(path)
      separators = toRunes("+++")
    var i = 0
    for word in split(mdFile, separators, maxsplit=6):
      if i == 3:
        let frontmatter = parsetoml.parseString(word)
        page_title = frontmatter["title"].getStr()
        page_date  = frontmatter["date"].getStr()
        page_categories = frontmatter["taxonomies"]["categories"].getElems()
        page_tags = frontmatter["taxonomies"]["tags"].getElems()
        pages.add(PageConfig(date: page_date, title: page_title, name: file_name))
        inc(i)
      elif i == 6:
        page_content = markdown(word)
        inc(i)
      else:
        inc(i)
    let
      publicDirPath  = "public/content/" & file_name
      publicFilePath = publicDirPath & "/index.html"
      pageHtml   = generatePageHtml(config_title, base_url, page_date_fmt, page_title, page_content, page_categories, page_tags)
    createDir(publicDirPath)
    writeFile(publicFilePath, pageHtml)
  let
    sortedPages = sortedByIt(pages, it.date)
    indexHtml = generateIndexHtml(config_title, base_url, sortedPages)
  echo sortedPages
  writeFile("public/index.html", indexHtml)
  echo $countChange & " page(s) created."


proc init(siteName: string) =
  createDir siteName
  createDir siteName & "/content"
  createDir siteName & "/templates"
  createDir siteName & "/static"
  createDir siteName & "/public"
  createDir siteName & "/public/content"
  writeFile(siteName & "/config.toml", configTemplate)

when isMainModule:
  import cligen
  dispatchMulti([build], [init])