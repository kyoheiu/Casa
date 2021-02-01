import markdown, unicode, json, os, tables, strutils, algorithm, sequtils

include "templates/page_base.nimf"
include "templates/index_base.nimf"
include "templates/taxonomies_base.nimf"

type
  SiteConfig = object
    title: string
    url: string
  PageConfig = object
    date: string
    title: string
    name: string
    category: seq[JsonNode]
    tag: seq[JsonNode]

var
  countChange = 0

var
  frontMatter: JsonNode
  pageDate, pageTitle, pageContent: string
  pageCategories, pageTags: seq[JsonNode]
  pageConfig: PageConfig
  pageConfigList: seq[PageConfig]
  siteConfig: SiteConfig
  siteTitle, siteUrl: string
  fileName: string

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

proc parsePageConfig(frontMatter: JsonNode, fileName: string): PageConfig =
  let
    pageDate = frontMatter["date"].getStr()
    pageTitle = frontMatter["title"].getStr()
    pageCategories = frontMatter["categories"].getElems()
    pageTags = frontMatter["categories"].getElems()
    pageConfig = PageConfig(date: pageDate, title: pageTitle, name: fileName, category: pageCategories, tag: pageTags)
  result = pageConfig

proc parsePageContentToHtml(contentFileDir: string, fileName: string): string = 
  let mdFile = readFile(contentFileDir & "/" & fileName & ".md")
  result = markdown(mdFile)

proc generateCategoriesList(pageConfigList: seq[PageConfig]): seq[JsonNode] =
  var categoriesList: seq[seq[JsonNode]]
  for page in pageConfigList:
    categoriesList.add(page.category)
  result = categoriesList.deduplicate.concat

proc generateTagsList(pageConfigList: seq[PageConfig]): seq[JsonNode] =
  var tagsList: seq[seq[JsonNode]]
  for page in pageConfigList:
    tagsList.add(page.tag)
  result = tagsList.deduplicate.concat

proc hasCategory(pageConfigList: seq[PageConfig], categoryName: JsonNode): seq[PageConfig] =
  var hasCategoryList: seq[PageConfig]
  for pageConfig in pageConfigList:
    if any(pageConfig.category, proc(x: JsonNode): bool = x == categoryName):
      hasCategoryList.add(pageConfig)
  result = hasCategoryList

proc hasTag(pageConfigList: seq[PageConfig], tagName: JsonNode): seq[PageConfig] =
  var hasTagList: seq[PageConfig]
  for pageConfig in pageConfigList:
    if any(pageConfig.tag, proc(x: JsonNode): bool = x == tagName):
      hasTagList.add(pageConfig)
  result = hasTagList

proc build() =
  removeDir("public")
  createDir("public") # 0.000s
  siteConfig = parseSiteConfig("config.json")
  for cssFile in walkFiles("css/*.css"):
    copyFileToDIr(cssfile, "public") # 0.005s
  for contentFileDir in walkDirs("content/*"):
    fileName = splitPath(contentFileDIr).tail # 0.005s 
    frontMatter = parseFile(contentFileDir & "/" & fileName & ".json") # 0.006s
    pageContent = parsePageContentToHtml(contentFileDir, fileName) # 0.0770s
    pageConfig = parsePageConfig(frontMatter, fileName)
    pageConfigList.add(pageConfig) # 0.0771s
    let
      publicDirPath  = "public/content/" & fileName
      publicFilePath = publicDirPath & "/index.html"
      pageHtml  = generatePageHtml(siteTitle, siteUrl, pageContent, pageConfig.date, pageConfig.title, pageConfig.category, pageConfig.tag)
    createDir(publicDirPath)
    writeFile(publicFilePath, pageHtml)
    inc(countChange)
  let
    sortedPageConfigList = pageConfigList.sortedByIt((it.date, it.name)).reversed
    indexHtml = generateIndexHtml(siteTitle, siteUrl, sortedPageConfigList)
  writeFile("public/index.html", indexHtml)
  
  let
    categoriesList = generateCategoriesList(sortedPageConfigList)
    tagsList = generateTagsList(sortedPageConfigList)
    categoryDirPath = "public/categories"
    tagDirPath = "public/tags"

  createDir(categoryDirPath)
  createDir(tagDirPath)
  for categoryName in categoriesList:
    let categoryHtml = generateTaxonomiesHtml(siteTitle, siteUrl, categoryName, hasCategory(sortedPageConfigList, categoryName))
    writeFile(categoryDirPath & "/" & $categoryName & ".html", categoryHtml)
  for tagName in tagsList:
    let tagHtml = generateTaxonomiesHtml(siteTitle, siteUrl, tagName, hasTag(sortedPageConfigList, tagName))
    writeFile(tagDirPath & "/" & $tagName & ".html", tagHtml)

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