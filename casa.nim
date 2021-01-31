import markdown, unicode, json, os, tables, strutils, algorithm

include "templates/page_base.nimf"
include "templates/index_base.nimf"

type
  SiteConfig = object
    title: string
    url: string
  PageConfig = object
    date: string
    title: string
    name: string
  PageTaxonomies = object
    category: seq[JsonNode]
    tag: seq[JsonNode]

var
  countChange = 0

var
  frontMatter: JsonNode
  pageDate, pageTitle, pageContent: string
  pageCategories, pageTags: seq[JsonNode]
  pageConfig: PageConfig
  pageTaxonomies: PageTaxonomies
  pageConfigList: seq[PageConfig]
  pageTaxonomiesList: seq[PageTaxonomies]
  siteConfig: SiteConfig
  siteTitle, siteUrl: string
  fileName: string
  countContent: int

const
  configTemplate = """
siteUrl = "https://example.com"
siteTitle = "site title"
"""

proc parseSiteConfig(file: string): SiteConfig =
  let siteConfigJson = parseFile(file)
  siteTitle = siteConfigJson["siteTitle"].getStr()
  siteUrl = siteConfigJson["siteUrl"].getStr()
  siteConfig = SiteConfig(title: siteTitle, url: siteUrl)
  return siteConfig


proc parsePageContentToHtml(contentFileDir: string, fileName: string): string = 
  let mdFile = readFile(contentFileDir & "/" & fileName & ".md")
  result = markdown(mdFile)

proc parsePageConfig(frontMatter: JsonNode, fileName: string): PageConfig =
  let
    pageDate = frontMatter["date"].getStr()
    pageTitle = frontMatter["title"].getStr()
    pageConfig = PageConfig(date: pageDate, title: pageTitle, name: fileName)
  result = pageConfig

proc parsePageTaxonomies(frontMatter: JsonNode): PageTaxonomies = 
  let
    pageCategories = frontMatter["categories"].getElems()
    pageTags = frontMatter["categories"].getElems()
    pageTaxonomies = PageTaxonomies(category: pageCategories, tag: pageTags)
  result = pageTaxonomies

proc build() =
  removeDir("public")
  createDir("public")
  siteConfig = parseSiteConfig("config.json")
  for cssFile in walkFiles("css/*.css"):
    copyFileToDIr(cssfile, "public")
  for contentFileDir in walkDirs("content/*"):
    fileName = splitPath(contentFileDIr).tail
    frontMatter = parseFile(contentFileDir & "/" & fileName & ".json")
    pageContent = parsePageContentToHtml(contentFileDir, fileName)
    pageConfig = parsePageConfig(frontMatter, fileName)
    pageConfigList.add(pageConfig)
    pageTaxonomies = parsePageTaxonomies(frontMatter)
    pageTaxonomiesList.add(pageTaxonomies)
    let
      publicDirPath  = "public/content/" & fileName
      publicFilePath = publicDirPath & "/index.html"
      pageHtml   = generatePageHtml(siteTitle, siteUrl, pageContent, pageConfig.date, pageConfig.title, pageTaxonomies.category, pageTaxonomies.tag)
    createDir(publicDirPath)
    writeFile(publicFilePath, pageHtml)
    inc(countChange)
  let
    sortedPageConfigList = pageConfigList.sortedByIt((it.date, it.name)).reversed
    indexHtml = generateIndexHtml(siteTitle, siteUrl, sortedPageConfigList)
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