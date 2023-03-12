import QtQuick 2.0
import QtQuick.Dialogs 1.0
import QtQuick.Controls 2.0
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    menuPath: "Plugins.ExportStaffMP3s"
    description: "Description goes here"
    version: "1.0"
    requiresScore: true
    pluginType: "dialog"
    id: window
    width: 400
    height: 320



    QProcess {
        id: proc
    }

    function dirname(p) {
        return (p.slice(0,p.lastIndexOf("/")+1))
    }
    
    function basename(p) {
        return (p.slice(p.lastIndexOf("/")+1))
    }

    function extension(p) {
        return (p.slice(p.lastIndexOf(".")+1))
    }
    function showObject(oObject) {
        
        if (Object.keys(oObject).length >0) {
            Object.keys(oObject)
                .filter(function(key) {
                    return oObject[key] != null;
                })
                .sort()
                .forEach(function eachKey(key) {
                    console.log("---- ---- ", key, " : <", oObject[key], ">");
                });
        }
    }
    function instrumentId2newPart(instID) {
        switch (instID) {
            case "brass.trumpet":
                instID = "trumpet"
                break;
            case "brass.trombone":
                instID = "trombone-treble"
                break;
            case "brass.sousaphone":
                instID = "bb-sousaphone-treble"
                break;
        }
        return instID
    }
    onRun: {

    }
    function getLocalPath(path) {
        path = path.replace(/^(file:\/{2})/,"")
        if (Qt.platform.os == "windows") path = path.replace(/^\//,"")
        path = decodeURIComponent(path)
        return path
    }
    function exportMP3(infile, outfile) {
        var cmd = '"'+Qt.application.arguments[0]+'" "'+infile+'" -o "'+outfile+'"'
        proc.start(cmd);
        var val = proc.waitForFinished(-1);
        if (val) {
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            console.log("command failed: "+cmd)
        }
    }
    function mkdir(path) {
        if (["linux", "osx"].indexOf(Qt.platform.os)>=0) {
            var cmd ='mkdir "'+path+'"'
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else if (Qt.platform.os=="windows") {
            cmd = "Powershell.exe -Command \"New-Item -Path '"+path+"' -ItemType Directory\""
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            console.log("unknown os",Qt.platform.os)
        }
    }
    function rmdir(path) {
        if (["linux", "osx"].indexOf(Qt.platform.os)>=0) {
            var cmd = 'rm -rf "'+path+'"'
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else if (Qt.platform.os=="windows") {
            var cmd = "Powershell.exe -Command \"Remove-Item '"+path+"' -Recurse\""
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            console.log("unknown os",Qt.platform.os)
        }
    }
    function exportStaffs(destFolder) {
        var score = curScore
        var origPath = score.path
        var cdir = dirname(origPath)
        var cname = basename(origPath)
        cname = baseFileName.text != '' ? baseFileName.text : cname.slice(0, cname.lastIndexOf('.'))
        console.log(score.scoreName, score.nstaves)
        console.log(cdir, cname)

        mkdir(destFolder+"tempFolder/")

        // add metronome
        var origWmetFname = destFolder+"tempFolder/"+cname+"-all.mscz"
        console.log("copy dest", origWmetFname)

        if (addMetronome.checked) {
            curScore.appendPart("temple-blocks")
            var msIdx = curScore.nstaves-1
            var cur = curScore.newCursor()
            cur.staffIdx = msIdx
            cur.voice = 0
            cur.rewind(0)
            cur.setDuration(1,4)
            // TODO: check measure type
            for (var i=0; i<curScore.nmeasures*4; i++) {
                if (cur.measure.firstSegment.tick == cur.segment.tick) {
                    cur.addNote(77, false)
                } else {
                    cur.addNote(76, false)
                }
            }
        }
        writeScore(curScore, origWmetFname,"mscz")

        // all staffs
        exportMP3(origWmetFname, destFolder+cname+"-all.mp3") // TODO: translate all
        console.log("did all mp3")

        if (score.nstaves>1) {
            for (var staff=0; staff<score.nstaves; staff++) {
                console.log("doing staff",staff)

                cur = curScore.newCursor()
                cur.staffIdx = staff
                cur.voice = 0
                cur.rewind(0)
                
                if (!exportNonPitched.checked && !cur.element.staff.part.hasPitchedStaff) {
                    continue
                }
                var instID = cur.element.staff.part.instrumentId
                console.log(instID)
                var inst = cur.element.staff.part.instruments[0]
                var instLongName = inst.longName.replace(" ","_")

                // modify dynamics
                var offs = 0
                for (var st=0; st<score.nstaves; st++) {
                    if (st==staff) {
                        console.log("ignoring staff",st)
                        offs = 0
                    } else {
                        if (restInBackground.checked) {
                            //offs = -40
                            offs = factorSlider.value
                        } else {
                            offs = -100
                        }
                    }
                    cur.staffIdx = st
                    for (var voice=0; voice<4; voice++) {
                        cur.voice = voice
                        cur.rewind(0)
                        while (cur.segment) {
                            if (cur.element) {
                                if (cur.element.type==Element.CHORD) {
                                    var c = cur.element
                                    for (var i=0; i<c.notes.length; i++) {
                                        var n = c.notes[i]
                                        n.veloOffset = Math.max(-100,offs)
                                    }
                                }
                            }
                            cur.next()
                        }
                    }
                }

                writeScore(curScore, destFolder+"tempFolder/"+cname+"-"+instLongName,"mscz")

                exportMP3(destFolder+"tempFolder/"+cname+"-"+instLongName+".mscz", destFolder+cname+"-"+instLongName+".mp3")

            }
        }
        
        closeScore(curScore)
        
        // remove tempfolder again
        rmdir(destFolder+"tempFolder/")        

        readScore(origPath, false)

        Qt.quit()
    }


    Item {
        anchors.fill: parent

        Rectangle {
            id: backgroundRect
            color: "#EEEEEE"
            width: parent.width
            height: parent.height

            Column {
                spacing: 10

                CheckBox {
                    id: exportNonPitched
                    checked: false
                    text: qsTr("Export non pitched staffs")
                    onCheckedChanged: function () {
                    }
                }

                CheckBox {
                    id: restInBackground
                    checked: true
                    text: qsTr("Export other staffs but quieter")
                    onCheckedChanged: function () {
                    }
                }

                Row {
                    width: childrenRect.width
                    height: childrenRect.height
                    spacing: 4

                    Label {
                            id: factorSliderLabel
                            text: qsTr("Silencing factor")
                            visible: restInBackground.checked
                            anchors.verticalCenter: factorSlider.verticalCenter
                            anchors.leftMargin: 4
                    }

                    Slider {
                            id: factorSlider
                            visible: restInBackground.checked
                            anchors.leftMargin: 8
                            value: -48
                            from: -127
                            to: 0
                            onMoved: function() {
                                console.log("slider",factorSlider.value)
                            }
                    }

                    Label {
                            id: factorSliderValueLabel
                            text: Math.floor(factorSlider.value)
                            visible: restInBackground.checked
                            anchors.verticalCenter: factorSlider.verticalCenter
                            anchors.leftMargin: 4
                    }
                }

                CheckBox {
                    id: addMetronome
                    checked: true
                    text: qsTr("Add metronome to output")
                }

                Label {
                    text: qsTr("After choosing the output wait for this window to close")
                }
                
                TextField {
                    id: baseFileName
                    placeholderText: qsTr("Base file name")
                    validator: RegExpValidator { regExp: /[^\\|/|:|*|?|\"|<|>|\|]+/ }
                }

                Row {
                    spacing: 10

                    Button {
                        id : buttonSaveOutput
                        text: qsTr("Export")
                        onClicked: {
                            console.log("export")
                            saveFileDialog.open()
                        }
                    }

                    Button {
                        id : buttonCancel
                        text: qsTr("Cancel")
                        onClicked: {
                            Qt.quit();
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: saveFileDialog
        title: qsTr("Output destination")
        selectExisting: false
        selectFolder: true
        selectMultiple: false
        onAccepted: {
                var filename = saveFileDialog.fileUrl.toString()
                console.log("Selected",filename)
                
                if(filename){

                    filename = getLocalPath(filename)
                    filename = dirname(filename+"/")
                    console.log("filename",filename)
                    exportStaffs(filename)

                    //Qt.quit()

                }
        }
    }
}
