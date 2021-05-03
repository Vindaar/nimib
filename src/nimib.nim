import os
import nimib / [types, blocks, docs, renders, paths]
export types, blocks, docs, renders, paths
from nimib/defaults import nil
export defaults.useLatex, defaults.darkMode
# types exports mustache, tables
# paths exports pathutils
from mustachepkg/values import searchTable, searchDirs, castStr
export searchTable, searchDirs, castStr


template nbInit*() =
  # I think I want to migrate to a single global object nb
  # with nb.doc as nbDoc and nb.block (or nb.blk?) as nbBlock
  # the global object will also contain all those paths

  # all paths are absolute, use relPath to have path relative to Project directory
  let
    nbThisFile {.inject.} = instantiationInfo(-1, true).filename.AbsoluteFile
    thisTuple = nbThisFile.splitFile
    nbThisDir {.inject.}: AbsoluteDir = thisTuple.dir
    nbThisName {.inject, used.}: string = thisTuple.name
    nbThisExt {.inject, used.}: string = thisTuple.ext
    nbInitDir {.inject, used.} = getCurrentDir().AbsoluteDir # current directory at initialization
  var
    nbUser {.inject.}: string = getUser()
    nbHomeDir {.inject.}: AbsoluteDir = findNimbleDir(nbThisDir)
  if dirExists(nbHomeDir / "docs".RelativeDir):
    nbHomeDir = nbHomeDir / "docs".RelativeDir
  setCurrentDir nbHomeDir

  # could change to nb.rel with nb global object
  proc relPath(path: AbsoluteFile | AbsoluteDir): string =
    (path.relativeTo nbHomeDir).string
    
  var
    nbDoc {.inject.}: NbDoc
    nbBlock {.inject.}: NbBlock

  nbDoc.author = nbUser  # never really used it yet, but probably could be a strdefine
  nbDoc.filename = changeFileExt(nbThisFile.string, ".html")

  nbDoc.render = renderHtml
  nbDoc.templateDirs = @["./", "./templates/"]
  nbDoc.partials = initTable[string, string]()
  nbDoc.context = newContext(searchDirs = @[])
  nbDoc.context["home_path"] = (nbHomeDir.relativeTo nbThisDir).string
  nbDoc.context["here_path"] = (nbThisFile.relativeTo nbHomeDir).string
  nbDoc.context["source"] = read(nbThisFile)

  defaults.init(nbDoc)

  when defined(nimibCustomPostInit):
    include nbPostInit

  template nbText(body: untyped) =
    nbTextBlock(nbBlock, nbDoc, body)

  template nbCode(body: untyped) =
    nbCodeBlock(nbBlock, nbDoc, body)
  
  template nbFree(body: untyped) =
    # do I need it with a body?
    nbFreeBlock(nbBlock, nbDoc, body)
  
  template nbNew =
    nbFreeBlock(nbBlock, nbDoc): discard

  template nbImage(url: string, caption = "") =
    nbNew
    nbBlock.context["url"] = url
    nbBlock.context["caption"] = caption
    nbBlock.code = "nbImage(url = \"" & url & "\", caption = \"" & caption & "\")"
    nbBlock.renderPlan = @["partialImageSingle"]

  template nbSave =
    when defined(nimibCustomPreSave):
      include nbPreSave
    # order if searchDirs/searchTable is relevant: directories have higher priority. rationale:
    #   - in memory partial contain default mustache assets
    #   - to override/customize (for a bunch of documents) the best way is to modify a version on file
    #   - in case you need to manage additional exceptions for a specific document add a new set of partials before calling nbSave
    nbDoc.context.searchDirs(nbDoc.templateDirs)
    nbDoc.context.searchTable(nbDoc.partials)
    withDir(nbHomeDir):
      write nbDoc

  template nbShow =
    nbSave
    open nbDoc
