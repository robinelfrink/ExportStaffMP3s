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

    function getCurrentVolumes() {
        var result = [];
        for (var part in curScore.parts) {
            result[part] = [];
            for (var instrument in curScore.parts[part].instruments) {
                result[part][instrument] = [];
                for (var channel in curScore.parts[part].instruments[instrument].channels)
                    result[part][instrument][channel] = curScore.parts[part].instruments[instrument].channels[channel].volume;
            }
        }
        return result;
    }

    function restoreVolumes(volumes) {
        for (var part in volumes)
            for (var instrument in volumes[part])
                for (var channel in volumes[part][instrument])
                    curScore.parts[part].instruments[instrument].channels[channel].volume =
                        volumes[part][instrument][channel];
    }

    function exportStaffs(destFolder) {
        curScore.startCmd();

        // Remember current channel volumes
        var volumes = getCurrentVolumes();

        if (addMetronome.checked) {
            curScore.appendPart("temple-blocks");

            // https://github.com/XiaoMigros/metronome-audio-export/
            var cursor = curScore.newCursor();
            cursor.rewind(Cursor.SCORE_START);
            cursor.staffIdx = curScore.nstaves - 1;

            while (cursor.measure) {
                var count = cursor.tick
                cursor.setDuration(1, cursor.measure.timesigNominal.denominator);
                cursor.addNote(cursor.measure.firstSegment.tick == cursor.tick ? 76 : 77, false);
                cursor.rewindToTick(count);
                cursor.next();
            }
        }

        var cname = basename(curScore.path);
        cname = baseFileName.text != '' ? baseFileName.text : cname.slice(0, cname.lastIndexOf('.'));


        // all staffs
        writeScore(curScore, destFolder+cname+"-all", "mp3")
        console.log("did all mp3")

        for (var part in curScore.parts) {
            if (!exportNonPitched.checked && !curScore.parts[part].hasPitchedStaff)
                continue

            restoreVolumes(volumes);

            // Silence the other parts
            for (var otherPart in volumes)
                if (otherPart != part)
                    for (var instrument in volumes[otherPart])
                        for (var channel in volumes[otherPart][instrument])
                            if (restInBackground.checked)
                                curScore.parts[otherPart].instruments[instrument].channels[channel].volume += factorSlider.value;
                            else
                                curScore.parts[otherPart].instruments[instrument].channels[channel].volume -= 100;

            writeScore(curScore, destFolder+cname+"-"+curScore.parts[part].partName, "mp3");
        }

        restoreVolumes(volumes);

        curScore.endCmd();
        cmd("undo");
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
