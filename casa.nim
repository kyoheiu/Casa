import  nmark, unicode, json, os, tables, strutils, algorithm, sequtils
# import nimprof

include "templates/page_base.nimf"
include "templates/index_base.nimf"
include "templates/taxonomies_base.nimf"

type
  SiteConfig = ref object
    title: string
    url: string
  PageConfig = ref object
    date: string
    title: string
    categories: seq[string]
    tags: seq[string]
    filename: string

var
  countChange = 0
var
  frontMatter: JsonNode
  pageContent: string
  pageConfig: PageConfig
  pageConfigList: seq[PageConfig]
  siteConfig: SiteConfig
  siteTitle, siteUrl: string
  fileName: string

const
  configTemplate = """
{
  "siteUrl": "https://example.com",
  "siteTitle": "site title"
}
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

proc generateCategoriesList(pageConfigList: seq[PageConfig]): seq[string] =
  var categoriesList: seq[seq[string]]
  for page in pageConfigList:
    categoriesList.add(page.categories)
  result = categoriesList.deduplicate.concat

proc generateTagsList(pageConfigList: seq[PageConfig]): seq[string] =
  var tagsList: seq[seq[string]]
  for page in pageConfigList:
    tagsList.add(page.tags)
  result = tagsList.deduplicate.concat

proc hasCategory(pageConfigList: seq[PageConfig], categoryName: string): seq[PageConfig] =
  var hasCategoryList: seq[PageConfig]
  for pageConfig in pageConfigList:
    if any(pageConfig.categories, proc(x: string): bool = x == categoryName):
      hasCategoryList.add(pageConfig)
  result = hasCategoryList

proc hasTag(pageConfigList: seq[PageConfig], tagName: string): seq[PageConfig] =
  var hasTagList: seq[PageConfig]
  for pageConfig in pageConfigList:
    if any(pageConfig.tags, proc(x: string): bool = x == tagName):
      hasTagList.add(pageConfig)
  result = hasTagList

proc build() =
  removeDir("public")
  createDir("public") # 0.000s
  siteConfig = parseSiteConfig("config.json")
  # move css file to public
  copyDir("css", "public/css")
  # for each content, generate content-html and config object
  for contentFileDir in walkDirs("content/*"):
    fileName = splitPath(contentFileDIr).tail # 0.005s
    pageContent = parsePageContentToHtml(contentFileDir, fileName) # 0.0770s
    frontMatter = parseFile(contentFileDir & "/" & fileName & ".json")
    frontMatter["filename"] = newJString(fileName)
    pageConfig = to(frontMatter, PageConfig)
    pageConfigList.add(pageConfig) # 0.0771s
    let
      publicDirPath  = "public/content/" & fileName
      publicFilePath = publicDirPath & "/index.html"
      pageHtml  = generatePageHtml(siteTitle, siteUrl, pageContent, pageConfig.date, pageConfig.title, pageConfig.categories, pageConfig.tags)
    createDir(publicDirPath)
    writeFile(publicFilePath, pageHtml)
    inc(countChange)
  # generate index.html based on sorted contents list
  let
    sortedPageConfigList = pageConfigList.sortedByIt((it.date, it.title)).reversed
    indexHtml = generateIndexHtml(siteTitle, siteUrl, sortedPageConfigList)
  writeFile("public/index.html", indexHtml)
  # generate taxonomies page based on sorted and filtered contents list
  let
    categoriesList = generateCategoriesList(sortedPageConfigList)
    tagsList = generateTagsList(sortedPageConfigList)
  for categoryName in categoriesList:
    let categoryHtml = generateTaxonomiesHtml(siteTitle, siteUrl, categoryName, hasCategory(sortedPageConfigList, categoryName))
    createDir("public/categories/" & categoryName)
    writeFile("public/categories/" & categoryName & "/index.html", categoryHtml)
  for tagName in tagsList:
    let tagHtml = generateTaxonomiesHtml(siteTitle, siteUrl, tagName, hasTag(sortedPageConfigList, tagName))
    createDir("public/tags/" & tagName)
    writeFile("public/tags/" & tagName & "/index.html", tagHtml)
  # echo the number of pages
  echo $countChange & " page(s) created."

proc init(siteName: string) =
  createDir siteName
  createDir siteName & "/content"
  createDir siteName & "/templates"
  createDir siteName & "/static"
  writeFile(siteName & "/config.json", configTemplate)

proc server() =
  discard execShellCmd("nimhttpd public")

when isMainModule:
  import cligen
  dispatchMulti([build], [init], [server])
