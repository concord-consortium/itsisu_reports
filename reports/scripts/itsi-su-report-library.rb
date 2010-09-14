require 'erb'
require 'base64'
require 'rexml/document'
require 'rexml/formatters/pretty'

include_class 'org.concord.framework.otrunk.OTChangeListener'
include_class 'org.concord.framework.otrunk.OTUser'
include_class 'org.concord.framework.otrunk.OTrunk'
include_class 'org.concord.framework.otrunk.view.OTUserListService'
include_class 'org.concord.framework.otrunk.wrapper.OTString'
include_class 'org.concord.otrunk.script.ui.OTScriptVariable'
include_class 'org.concord.otrunk.ui.OTCheckBox'
include_class 'org.concord.otrunk.ui.OTChoice'
include_class 'org.concord.otrunk.ui.OTImage'
include_class 'org.concord.otrunk.ui.OTText'
include_class 'org.concord.otrunk.ui.question.OTQuestion'
include_class 'org.concord.graph.util.state.OTDrawingTool'
include_class 'org.concord.datagraph.state.OTDataCollector'
include_class 'org.concord.otrunk.ui.snapshot.OTSnapshotAlbum'

ROWCOLOR1 = "#FFFEE9"
ROWCOLOR2 = "#FFFFFF"

def render(templateBlob)
  erb = ERB.new Java::JavaLang::String.new(templateBlob.src).trim.to_s
  srcProp = templateBlob.otClass().getProperty("src")
  srcValue = templateBlob.otGet(srcProp)  
  erb.filename = srcValue.getBlobURL().toExternalForm()
  erb.result(binding)   
end 

def sysProp(prop, default)
  Java::JavaLang::System.getProperty(prop, default)
end

def objectIdStr(obj)
  begin
    obj.getGlobalId().toInternalForm()
  rescue NoMethodError
  	obj.otExternalId()
  end
end

def embedObject(obj, viewEntry=nil)
  return if obj.nil?
  tag = "<object refid=\"#{ objectIdStr(obj) }\" "
  tag += "viewid=\"#{ objectIdStr(viewEntry) }\" "  if viewEntry
  tag += "/>"
end

def linkToObject(link_text, obj, viewEntry=nil, frame=nil)
  link = "<a href=\"#{ objectIdStr(obj) }\" "
  link += "viewid=\"#{ objectIdStr(viewEntry) }\" "  if viewEntry
  link += "target=\"#{ objectIdStr(frame) }\" " if frame
  link += ">#{link_text}</a>"
end

def linkToObjectAction(link_text, obj, action)
  viewEntryCopy = $otObjectService.copyObject($viewEntry, 1)
  viewEntryCopy.variables.add(otCreate(OTScriptVariable){|scriptVar|
    scriptVar.name="action"
    scriptVar.reference = otCreate(OTString){|str|
      str.string=action
    }
  })
  "<a href=\"#{ obj.otExternalId() }\" viewid=\"#{viewEntryCopy.otExternalId()}\">#{link_text}</a>"
end

def users
  userListService = $viewContext.getViewService(OTUserListService.java_class)
  userListService.getUserList().sort_by { |user| #sort users by name
    (user.name && !user.name.empty?) ? user.name.downcase.split.values_at(-1, 0) : ['']
  }
end

def embedUserObject(obj, user)
  "<object refid=\"#{ obj.otExternalId() }\" user=\"#{ user.getUserId().toExternalForm() }\"/>"
end

def hasUserModified(obj, user)
  @otrunk.hasUserModified(obj, user)
end

def userObject(obj, user)
  @otrunk.getUserRuntimeObject(obj, user);
end

def otCreate(rconstant)
  otObj = $otObjectService.createObject(rconstant.java_class)
  if block_given?
    yield otObj
  end
  otObj
end


# For Investigations reporting,
# have a look @otrunk.realRoot or @otrunk.system.library
# Interfaces are OTrunkImpl and OTSystem
def rootObject
  @otrunk.root
end

def parseBodyText
  bodyText = activityRoot.bodyText
  pattern = /<object\s*refid=\s*"([^\"]*)"[^>]*>/i
  results = []
  local_ids = bodyText.scan(pattern) do |matchgroup|
    id = matchgroup.first
    local_id = id.match(/[0-9|a-f|-]+!\/(.*)/)[1]
    result = {
     :id => id.strip,
     :local_id => local_id.strip
    }
    results << result
  end
  return results
end
   
def activityDatabase
  return @otrunk.getOTDatabase(activityRoot.globalId)
end
  
def localIDToGlobalId(local_id)
  activityDatabase.getOTIDFromLocalID(local_id)
end

def truncate(string, length)
  postFix = ""
  postFix = "..." if string.length > length
  string[0...length] + postFix
end

def popupFrame
  return @frame if @frame 
  @frame = otCreate(org.concord.framework.otrunk.view.OTFrame) { |frame|
    frame.width=800
    frame.height=600
   }
end

def popupLinkToObject(link_text, obj, viewEntry=nil, user=nil)
#  frame = popupFrame
#  link = "<a href=\"#{ obj.otExternalId() }\" "
#  link += "viewid=\"#{ viewEntry.otExternalId() }\" "  if viewEntry
#  link += "user=\"#{ user.otExternalId() }\" "  if user
#  link += " target=\"#{ popupFrame.otExternalId }\">#{link_text}</a>"  
end


def sectionFor(question)
  return question[:section] || "unknown section"
end

def plainPromptText(question)
  toPlainText(promptText(question))
end

def toPlainText(obj)
  text = ''
  if obj.is_a? org.concord.otrunk.view.document.OTCompoundDoc
    text = obj.bodyText
  elsif obj.is_a? org.concord.otrunk.ui.OTText
    text = obj.text
  elsif obj.is_a? String
    text = obj
  end
  text.gsub!(/<.*?>/, '')
  text.gsub!(/\s+/, ' ')
  text.strip
end

def activityRoot
  rootObject.reportTemplate.reference
end


def activityQuestions
  rootPage = activityRoot()
  if rootPage.nil?
    return nil
  end
  
  refs = rootPage.getDocumentRefs
  
  responses = parseBodyText
  responses = responses.map do |resp| 
    found = refs.find do |r|
      r.globalId.to_s =~ /#{resp[:local_id]}/i 
    end
    if found
      { :local_id => resp[:local_id],
        :id => resp[:id],
        :object => found,
        :section => findSection(resp[:local_id])
      }
    else
      nil
    end
  end
  responses.compact!
  return responses
end

def findSection(local_id)
  
  intro_s      = "Introduction"
  career_s     = "Career STEM"
  proced_s     = "Procedure"
  prediction_s = "Prediction"
  collect1_s   = "Collect (1)"
  collect2_s   = "Collect (2)"
  collect3_s   = "Collect (3)"
  analysis_s   = "Analysis"
  conclusion_s = "Conclusion"
  career2_s    = "Second career STEM"
  further_s    = "Further Inv."
  
  map = {
    "to_id_5"      => intro_s,
    "draw_id_6"    => intro_s,
      
    "to_id_career" => career_s, 
    
    "to_id_4"      => proced_s,
    "draw_id_1"    => proced_s,  
    
    "to_id_1"      => prediction_s,
    "draw_id_7"    => prediction_s,  
  
    "predict_id_1" => collect1_s,
    "dc_id_1"      => collect1_s,
    "to_id_6"      => collect1_s,
    "draw_id_2"    => collect1_s,
   
    "predict_id_2" => collect2_s,
    "dc_id_2"      => collect2_s,
    "to_id_8"      => collect2_s,
    "draw_id_3"    => collect2_s,
     
    "dc_id_3"      => collect3_s,
    "to_id_9"      => collect3_s,
    "draw_id_4"    => collect3_s,
    
    "to_id_2"      => analysis_s,
    "draw_id_8"    => analysis_s,
    
    "to_id_3"      => conclusion_s,
    "draw_id_9"    => conclusion_s,
    "to_id_career_2" => career2_s, 
    
    "dc_id_4"      => further_s,
    "to_id_7"      => further_s,
    "draw_id_5"    => further_s

  }
  return map[local_id]
end

def otherUserList(user)
  root = activityRoot()
   if root.is_a? org.concord.otrunkmw.OTModelerPage
     # there is no user list in this case, this is an very old style activity
     return ""
   end

   if not root.is_a? org.concord.otrunk.ui.OTLayerContainer
     # this is something else that we don't know how to handle
     return ""
   end
   
   if root.layers().size() != 2
     # this is something we don't know how to handle
     return ""
   end 
   
   # this is the object that does the scripting or deals with workgroups
   secondLayer = root.layers().get(1)
   
   if secondLayer.is_a? org.concord.otrunk.script.ui.OTScriptObject
     userNameListAuthored = secondLayer.variables.vector.select { |var| var.name.eql? "users"}[0].reference
     userNameList = userObject(userNameListAuthored, user)
     userNameList.objects.vector.collect { |name| name.text }.join(", ")
   elsif secondLayer.is_a? org.concord.otrunk.user.OTWorkgroupMemberChooser
     userSecondLayer = userObject(secondLayer, user)
     names = userSecondLayer.otherWorkgroupMembers.collect { |mem| mem.name }
     if userSecondLayer.leadMember
       names << userSecondLayer.leadMember.name
     end
     names = names - [user.name]
     names.join(", ")
   end 
end

def currentChoiceText(chooser, short=false)
  answer = chooser.currentChoice
  
  if answer == nil and chooser.currentChoices.size > 0
    
    strings = chooser.currentChoices.vector.collect do |item|
      text = toPlainText(item)
      text = truncate(text, 10) if short
      '<li>' + text + '</li>'
    end
    return '<ul style="margin-left: 15;">' + strings.join("\n") +  '</ul>'
  end
  
  return nil if answer == nil
  
  text = toPlainText(answer)
  text = truncate(text, 30) if short
  return text
end

# this takes a userQuestion
def questionAnswer(question, user=nil, short=true)
  type = getQuestionType(question)
  case type
  when 'text'
    answer = question.text.strip
    if (answer == nil || answer.length == 0)
      answer = 'No Answer'
    elsif short
      answer = truncate(answer, 80)
    end
  when 'album'
    # TODO: Figure out what to do with snapshots
    # answer = embedUserObject(question,user)
  when 'unknown'
    # do nothing
  else
    answer = embedUserObject(question,user)
  end
  answer
end

def correctAnswers(question)
  if question.correctAnswer.nil?
    answers = []
  elsif question.correctAnswer.is_a?(org.concord.framework.otrunk.wrapper.OTObjectSet)
    answers = question.correctAnswer.objects.vector
  else
    answers = [question.correctAnswer]
  end
end


# this takes a userQuestion
def questionCorrect (question)
  if question.input.is_a? org.concord.otrunk.ui.OTChoice
    if question.correctAnswer
      if question.correctAnswer.is_a? org.concord.framework.otrunk.wrapper.OTObjectSet
        return question.correctAnswer.objects.vector.contains_all(question.input.currentChoices.vector) &&
          question.input.currentChoices.vector.contains_all(question.correctAnswer.objects.vector)
      else
        chosenAnswer = question.input.currentChoice
        if chosenAnswer == nil && question.input.currentChoices.vector.size > 0
          chosenAnswer = question.input.currentChoices.vector.get(0)
        end
        return question.correctAnswer == chosenAnswer
      end
    end
  end
  
  return nil
end


def basicQuestionAnswerHtml(authoredQuestion, user, short=true)
  userQuestion = userObject(authoredQuestion, user)
  return questionAnswerHtml(userQuestion, user, short)
end

# this takes a userQuestion
def questionAnswerHtml(question, user=nil, short=true)
  correct = nil 
  text = questionAnswer question, user, short
  return text if correct == nil
  return "<font color=\"#ff0000\">#{text}</font>" unless correct
  return "<font color=\"#009900\">#{text}</font>"
end

  
# this takes a userQuestion
def questionAnswerText(question, user=nil, short=true)
  correct = questionCorrect question
  text = questionAnswer(question, user, short)
end

def isChoiceQuestion(question)
  return question.is_a? org.concord.otrunk.ui.OTChoice
end

def linkToMainReport(link_text)
  firstObject = rootObject.reportTemplate
  firstView = rootObject.reportTemplateViewEntry
  linkToObject link_text, firstObject, firstView
end

def getXmlReport
  "not happening"
end

# this is a kludge, but it works as long as the user's database is an XMLDatabase and is loaded from the SDS
# basically parse the SDS url for the user's workgroup id
def getUsersSdsWorkgroupId(user)
  sdsId = nil
  dbUrl = user.getOTObjectService().getMainDb().getContextURL()
  if dbUrl.to_s =~ /workgroups\/([0-9]+)\/ot_learner_data/
    sdsId = $1
  end
  return sdsId
end

def getQuestionElem(question, index)
  questionType = getQuestionType(question)
  elem = REXML::Element.new('question')
  elem.add_attributes('id' => (index + 1).to_s,
    'prompt' => plainPromptText(question),
    'type' => questionType)
  elem
end

def getAnswerElem(question, index, user)
  elem = REXML::Element.new('answer')
  elem.attributes['questionId'] = (index + 1).to_s
  case getQuestionType(question)
    when 'choice' then
      doChoiceAnswerElem(elem, question)
    when 'text' then
      doTextAnswerElem(elem, question)
    when 'image' then
      doImageAnswerElem(elem, question)
  else
    elem.text = 'UNKNOWN'
  end
  elem
end

def doChoiceAnswerElem(answerElem, question)
  currentChoices = getCurrentChoices(question.input)
  if currentChoices.size == 0
    answerElem.text = 'NO_ANSWER'
    return
  end
  choicesElem = answerElem.add_element('choices')
  currentChoices.each do |num, text|
    choiceElem = choicesElem.add_element('choice')
    choiceElem.add_attributes('num' => (num+1).to_s, 'text' => text)
  end
end

def doTextAnswerElem(answerElem, question)
  text = question.input.text
  answerElem.text = text.strip == '' ? 'NO_ANSWER' : text
end

def doImageAnswerElem(answerElem, question)
  url = getImageBlobUrl(question.input)
  if url
    imageElem = answerElem.add_element('image')
    imageElem.attributes['src'] =  url.toExternalForm
  else
    answerElem.text = 'NO_ANSWER'
  end
end

def getQuestionType(question)
  if question.is_a?(OTQuestion)
    input = question.input
  else
    input = question
  end
  if input.is_a?(OTChoice)
    return 'choice'
  elsif input.is_a?(OTText)
    return 'text'
  elsif input.is_a?(OTImage)
    return 'image'
  elsif input.is_a?(OTDrawingTool)
    return 'drawing'
  elsif input.is_a?(OTDataCollector)
    return 'datagraph'
  elsif input.is_a?(OTSnapshotAlbum)
    return 'album'
  else return "unknown"
  end
 
  return question
end

## Return a number corresponding to the choice, beginning with 0.
## choosers: an OTChoice
## choice: user's choice, as can be retrieved with getCurrentChoice()
def getChoiceNum(chooser, choice)
  num = -1
  chooser.getChoices.each_with_index do |option, i|
    if option.otExternalId == choice.otExternalId
      num = i
      break
    end
  end
  num
end

## Returns a list of pairs [choiceNum, choiceText]
def getCurrentChoices(chooser)
  choices = []
  answer = chooser.currentChoice
  
  if answer
    choices << [getChoiceNum(chooser, answer), toPlainText(answer)]
  elsif chooser.currentChoices.size > 0
    chooser.currentChoices.each do |item|
      choices << [getChoiceNum(chooser, item), toPlainText(item)]
    end
  end
  choices
end

## Percentage of users that answered correctly for the question
def correctUsersPercent(question, users)
  numCorrect = 0
  users.each do |user|
    numCorrect += 1 if questionCorrect(userObject(question, user))
  end
  return 0 if users.length < 1
  numCorrect.to_f / users.length * 100
end

## How much of the questions the user has answered
## e.g. Returns 0.0 when the user answered no questions,
## 50.0 when the user has answered half of the questions.
def completionRatio(user)
  cnt = 0;
  activityQuestions.each do |aq|
    question = aq[:object]
#    userQuestion = userObject(question, user)
    cnt += 1 if @otrunk.hasUserModified(question,user)
#    cnt += 1 if questionAnswer(userQuestion) != 'No Answer'
  end
  numQuestions = activityQuestions.length
  (numQuestions > 0 ? cnt.to_f / numQuestions : 1.0) * 100
end

## image: an OTImage
def getImageBlobUrl(image)
  url = ''
  if image.isResourceSet("imageBytes")
    # make sure the image has valid bytes
    #bytes = image.imageBytes
    #answer = "IMAGE[#{Base64.encode64(String.from_java_bytes(bytes))}]"
    #answer = "[Image]"
    imageBytesProp = image.otClass.getProperty('imageBytes')
    return nil if imageBytesProp.nil?

    blob = image.otGet(imageBytesProp)
    if blob.nil?
      return nil
    else
      url = blob.getBlobURL
      if url.nil?
        return nil
      else
        return url
      end
    end
  end
end

def multipleChoiceUsersBarGraph(question, users)
  correctAnswers = correctAnswers(question)
  data = [0] * question.input.choices.length
  if correctAnswers.empty?
    colors = ['0044dd'] * question.input.choices.length
  else
    colors = []
    question.input.choices.each_with_index do |choice, i|
      colors[i] = correctAnswers.include?(choice) ? '00cc44' : 'ff4400'
    end
  end
  users.each do |user|
    userQuestion = userObject(question, user)
    choices = getCurrentChoices(userQuestion.input)
    choices.each do |choice|
      num = choice[0]
      data[num] += 1
    end
  end
  xLabels = (1..data.length).to_a.join('|')
  colors = colors.join('|')
  googleBarGraph(data, xLabels, colors)
end

def googleBarGraph(bin, xLabels, colors)
  data = bin.join(',')
  ymax = bin.inject { |a, b| a > b ? a : b }
  yRangeMax = ymax * 1.1
  scale = "0,#{yRangeMax}"
  size = "#{100 * bin.length}x280"
  yInterval = ymax / 5
  yInterval = 1 if yInterval < 1
  yRange = "1,0,#{yRangeMax},#{yInterval}"
  "<img hspace=\"20\" src=\"http://chart.apis.google.com/chart?cht=bvs&chs=#{size}&chbh=35,25,40&chd=t:#{data}&chds=#{scale}&chxr=#{yRange}&chco=#{colors}&chxt=x,y&chxl=0:|#{xLabels}&chm=N*f0*,000000,0,-1,10\"/>"
end

class Toggler

  def initialize(x, y)
    @x = x
    @y = y
    @current = @y
  end
  
  def next
    @current = @current == @x ? @y : @x
  end
  
end
