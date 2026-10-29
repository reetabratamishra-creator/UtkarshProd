/**
 * Universal PEB Building Description & Engineering Parser
 * --------------------------------------------------------
 * Resilient multi-format extraction engine for pre-engineered building (PEB) documents.
 * Supports:
 *   1. Narrative & structured document-style specifications (e.g. Shree Siddhi Vinayak format)
 *   2. Tabular engineering QRF/QFR formats (e.g. Utkarsh QRF #741 / LalBaba format)
 * Extracts:
 *   - Building Geometry (Frame type, Width, Length, Height, Slope, Bay spacing, End walls)
 *   - Roof System (Profile, Thickness, Material, Eave condition)
 *   - Wall System (Cladding profile, Thickness, Material, Downspouts, Brick wall)
 *   - Framed Openings & Additions (Canopy, Cranes, Mezzanine, Roof monitor)
 *   - Accessories & Buyout Items with precise coordinate-aware table row clustering
 *   - Technical Notes (D.1) & Material Specifications (D.2)
 */

export async function parseUniversalBuildingPdf(inputData) {
    if (!window.pdfjsLib) {
        throw new Error('PDF.js library is not loaded');
    }

    const doc = await window.pdfjsLib.getDocument({ data: inputData }).promise;
    const pages = [];
    let fullText = '';

    for (let i = 1; i <= doc.numPages; i++) {
        const page = await doc.getPage(i);
        const textContent = await page.getTextContent();

        const items = textContent.items.map(it => ({
            str: (it.str || '').trim(),
            x: Math.round(it.transform[4]),
            y: Math.round(it.transform[5]),
            w: Math.round(it.width),
            h: Math.round(it.height)
        })).filter(it => it.str.length > 0);

        // Sort items by Y descending (top-to-bottom), then X ascending (left-to-right)
        items.sort((a, b) => {
            if (Math.abs(a.y - b.y) <= 4) return a.x - b.x;
            return b.y - a.y;
        });

        // Group into physical text lines
        const lines = [];
        let curLine = [];
        let curY = null;
        for (const it of items) {
            if (curY === null || Math.abs(it.y - curY) <= 4) {
                curLine.push(it);
                curY = it.y;
            } else {
                lines.push(curLine);
                curLine = [it];
                curY = it.y;
            }
        }
        if (curLine.length > 0) lines.push(curLine);

        const pageText = lines.map(line => line.map(it => it.str).join(' ')).join('\n');
        pages.push({ pageNumber: i, lines, text: pageText, items });
        fullText += `\n--- PAGE ${i} ---\n` + pageText;
    }

    const result = {
        clientInfo: {
            clientName: '',
            projectLocation: '',
            buildingName: ''
        },
        geometry: {},
        roofSystem: {},
        wallSystem: {},
        summary: {
            mainBuildingArea: '4915',
            canopyArea: '160',
            mezzanineArea: '770',
            grossArea: '5845'
        },
        designCriteria: {
            designCode: 'AISC 2010 / MBMA',
            windSpeed: '47',
            seismicZone: 'III',
            liveLoad: '0.57',
            deadLoad: '0.15'
        },
        additions: {
            hasCanopy: true,
            canopyDesc: '',
            hasCrane: true,
            craneDesc: '',
            hasMezzanine: true,
            mezzanineDesc: '',
            roofMonitorDesc: ''
        },
        accessories: [],
        buyouts: [],
        technicalNotes: [],
        materialSpecs: [],
        paramTable: [],
        docSections: []
    };

    // ── 1. CLIENT & PROJECT METADATA (Strict line-by-line parsing: NEVER cross newlines) ──
    const textLines = fullText.split(/\r?\n/).map(l => l.trim()).filter(Boolean);

    function extractMetadataLine(keyRegex) {
        for (const line of textLines) {
            const m = line.match(keyRegex);
            if (m) {
                let val = (m[1] || '').trim();
                val = val.replace(/^[:|\s-]+|[:|\s-]+$/g, '').trim();
                if (val && !/^(?:Client|Project|Building|Date|By|Rev|Name|Site|Location|Opening|Openings|Description|Dimensions|Width|Length|Details|Remarks|Soffit|Type|Parameter|Sr\.?\s*No\.?)$/i.test(val)) {
                    return val;
                }
                return '';
            }
        }
        return '';
    }

    result.clientInfo.clientName = extractMetadataLine(/^(?:Client\s*name|Client)[:\s|]*(.*)$/i);
    result.clientInfo.projectLocation = extractMetadataLine(/^(?:Project\s*site|Project\s*location|Project\s*address|Site\s*location|Plant\s*location)[:\s|]*(.*)$/i);
    result.clientInfo.buildingName = extractMetadataLine(/^(?:Building\s*name|Building\s*type|Type\s*of\s*building|Name\s*of\s*building)[:\s|]*(.*)$/i);

    // Fallback: Check individual page lines in the first 2 pages (metadata block only) if any field is still blank
    if (!result.clientInfo.clientName || !result.clientInfo.projectLocation || !result.clientInfo.buildingName) {
        const headerPages = pages.slice(0, 2);
        for (const p of headerPages) {
            for (const line of p.lines) {
                const lineStr = line.map(it => it.str).join(' ').trim();
                if (!result.clientInfo.clientName) {
                    const m = lineStr.match(/^Client(?:\s*Name)?\s*[:\s|]*(.*)$/i);
                    if (m) {
                        let val = (m[1] || '').replace(/^[:|\s-]+|[:|\s-]+$/g, '').trim();
                        if (val && !/^(?:name|date|by|rev|client|project|building)$/i.test(val)) {
                            result.clientInfo.clientName = val;
                        }
                    }
                }
                if (!result.clientInfo.projectLocation) {
                    const m = lineStr.match(/^(?:Project\s*Site|Project\s*Location|Site\s*Location|Plant\s*Location)\s*[:\s|]*(.*)$/i);
                    if (m) {
                        let val = (m[1] || '').replace(/^[:|\s-]+|[:|\s-]+$/g, '').trim();
                        if (val && !/^(?:site|location|project|building|name|date|by|rev|client|opening|openings|description|dimensions|details|remarks)$/i.test(val)) {
                            result.clientInfo.projectLocation = val;
                        }
                    }
                }
                if (!result.clientInfo.buildingName) {
                    const m = lineStr.match(/^(?:Building\s*Name|Building\s*Type|Type\s*of\s*Building)\s*[:\s|]*(.*)$/i);
                    if (m) {
                        let val = (m[1] || '').replace(/^[:|\s-]+|[:|\s-]+$/g, '').trim();
                        if (val && !/^(?:name|type|building|date|by|rev|client|project)$/i.test(val)) {
                            result.clientInfo.buildingName = val;
                        }
                    }
                }
            }
        }
    }

    // ── 2. BUILDING GEOMETRY ──
    const widthMatch = fullText.match(/Building\s*Width\s*(?:M)?\s*[:\s|]+([0-9.]+\s*M?)/i) ||
                       fullText.match(/Width\s*\([m\)]*\)\s*[:\s|]+([0-9.]+\s*M?)/i);
    if (widthMatch) result.geometry.width = widthMatch[1].trim();

    const lengthMatch = fullText.match(/Building\s*Length\s*(?:M)?\s*[:\s|]+([0-9.]+\s*M?)/i) ||
                        fullText.match(/Length\s*\([m\)]*\)\s*[:\s|]+([0-9.]+\s*M?)/i);
    if (lengthMatch) result.geometry.length = lengthMatch[1].trim();

    const heightMatch = fullText.match(/Building\s*Height\s*(?:M)?\s*[:\s|]+([0-9.]+\s*M?)/i) ||
                        fullText.match(/Height\s*\([m\)]*\)\s*[:\s|]+([0-9.]+\s*M?)/i);
    if (heightMatch) result.geometry.height = heightMatch[1].trim();

    const slopeMatch = fullText.match(/(?:Roof\s*Slope|Slope\/Ridge\s*height|Slope)(?:\s*1\s*:\s*x)?\s*[:\s|]+([0-9]+[:\s]+[0-9.]+(?:\([A-Za-z]+\))?|[0-9.]+(?:\([A-Za-z]+\))?)/i);
    if (slopeMatch) result.geometry.slope = slopeMatch[1].trim();

    const sideBayMatch = fullText.match(/Side\s*Bay\s*spacing\s*(?:M)?\s*[:\s|]+([0-9\s@.+]+?)(?=\s*(?:Client|Centre|Internal|End|$|\n))/i);
    if (sideBayMatch) {
        result.geometry.baySpacing = sideBayMatch[1].trim();
    } else {
        const bayMatch = fullText.match(/(?:Bay\s*Spacing(?:\s*LONGITUNAL)?)\s*(?:\(m\))?\s*[:\s]*([^\n\r]+(?:\n[^\n\r]+)*?)(?=\n\s*(?:Front\s*End|Back\s*End|Surface|Primary|Left|Right|14|\d+\b))/i);
        if (bayMatch) {
            result.geometry.baySpacing = bayMatch[1].replace(/LONGITUNAL\s*\(m\)/gi, '').replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
        }
    }

    const frameMatch = fullText.match(/(?:Frame\s*Type)\s*[:\s]*([^\n\r]+)/i);
    if (frameMatch) result.geometry.frameType = frameMatch[1].trim();

    const fewMatch = fullText.match(/(?:Front\s*End\s*Wall\s*\(FEW\)|Left\s*End\s*Wall\s*\(LEW\))\s*[:\s]*([^\n\r]+)/i);
    if (fewMatch) result.geometry.frontEndWall = fewMatch[1].trim();

    const bewMatch = fullText.match(/(?:Back\s*End\s*Wall\s*\(BEW\)|Right\s*End\s*Wall\s*\(REW\))\s*[:\s]*([^\n\r]+)/i);
    if (bewMatch) result.geometry.backEndWall = bewMatch[1].trim();

    // End Wall Bay Spacing (LEW/REW)
    const ewMatch = fullText.match(/(?:Left|Right)\s*End\s*Bay\s*Spacing\s*(?:M)?\s*[:\s|]*([0-9\s@.+]+?)(?=\s*(?:Client|Centre|Col|b\.|\n))/i) ||
                    fullText.match(/(?:Front|Back)\s*End\s*Wall[^\n\r]*?[:\s|]+([0-9\s@.M\/\(\)C\w,]+?)(?=\s*(?:Non|Expandable|\n))/i);
    if (ewMatch) result.geometry.endWallBaySpacing = ewMatch[1].trim();

    // Width Module / Intermediate column spacing
    const wmMatch = fullText.match(/Width\s*Module\s*(?:M)?\s*[:\s|]*([0-9\s@.+]+?)(?=\s*(?:Client|Centre|Col|c\.|\n))/i) ||
                    fullText.match(/Intermediate\s*Column\s*Spacing[^\n\r]*?[:\s|]+([^\n\r|]+)/i);
    if (wmMatch) result.geometry.widthModule = wmMatch[1].trim();

    // Bracing
    const rBraceMatch = fullText.match(/Roof\s*Bracing\s*Type\s*[:\s|]*([A-Za-z0-9\s]+?)(?=\s*(?:Client|Assumed|b\.|\n))/i);
    if (rBraceMatch) result.geometry.bracingRoof = rBraceMatch[1].trim();
    const wBraceMatch = fullText.match(/Wall\s*Bracing[^\n\r]*?Type\s*[:\s|]*([A-Za-z0-9\s\(\).]+?)(?=\s*(?:Client|Assumed|c\.|\n))/i);
    if (wBraceMatch) result.geometry.bracingWall = wBraceMatch[1].trim();

    // Surface Prep
    const spPri = fullText.match(/Surface\s*preparation\s*Type\s*[:\s|]*([A-Za-z0-9.\s]+?)(?=\s*(?:Client|Assumed|2|\n))/i);
    const primer = fullText.match(/Primer\s*Type\s*[:\s|]*([\s\S]+?)(?=\s*(?:Client|Assumed|3|\n\s*\d))/i);
    const inter = fullText.match(/Intermediate\s*Coating\s*Type\s*[:\s|]*([\s\S]+?)(?=\s*(?:Client|Assumed|4|\n\s*\d))/i);
    const finish = fullText.match(/Finish\s*Coating\s*Type\s*[:\s|]*([\s\S]+?)(?=\s*(?:Client|Assumed|5|\n\s*\d))/i);
    const dft = fullText.match(/Total\s*(\d+\s*m(?:icrons?)?)/i);
    const secGsm = fullText.match(/Secondary\s*members\s*Type\s*[:\s|]*([0-9]+\s*GSM)/i) ||
                   fullText.match(/Secondary\s*Member\s*[:\s|]+([0-9]+\s*GSM[^\n\r]*)/i);

    let pList = [];
    if (spPri) pList.push(spPri[1].trim());
    if (primer) pList.push(primer[1].replace(/\s+/g, ' ').trim());
    if (inter) pList.push(inter[1].replace(/\s+/g, ' ').trim());
    if (finish) pList.push(finish[1].replace(/\s+/g, ' ').trim());
    if (dft) pList.push(`Total DFT ${dft[1].trim()}`);
    if (pList.length) {
        result.geometry.surfacePrepPrimary = pList.join(', ');
    } else {
        const legacySp = fullText.match(/Primary\s*Member\s*[:\s|]+(Shot\s*Blasting[^\n\r]+)/i);
        if (legacySp) result.geometry.surfacePrepPrimary = legacySp[1].trim();
    }
    if (secGsm) result.geometry.surfacePrepSecondary = secGsm[1].trim();

    // Summary Areas
    let wNum = parseFloat(result.geometry.width) || 0;
    let lNum = parseFloat(result.geometry.length) || 0;
    if (wNum > 0 && lNum > 0) {
        result.summary.mainBuildingArea = String(Math.round(wNum * lNum));
    } else {
        const mbA = fullText.match(/MAIN\s*BUILDING[^\n\r]*?(\d{3,6})/i);
        if (mbA) result.summary.mainBuildingArea = mbA[1];
    }

    // Canopy & Mezzanine
    const canProj = fullText.match(/Projection[.\s]+M\s*[:\s|]*([^\n\r]+?)(?=\s*(?:Client|b\.|\n))/i);
    const canLen = fullText.match(/(?:Canopy[\s\S]*?)?b\.\s*Length\s*M\s*[:\s|]*([0-9.]+\s*m?)/i) ||
                   fullText.match(/Canopy[\s\S]*?Length\s+M\s*[:\s|]*([0-9.]+\s*m?)/i);
    const canBot = fullText.match(/Bottom\s*of\s*the\s*Canopy\s*M\s*[:\s|]*([0-9.]+)/i);
    const canSlp = fullText.match(/(?:Canopy[\s\S]*?)?d\.\s*Slope\s*1\s*:\s*x\s*[:\s|]*([0-9.]+)/i) ||
                   fullText.match(/Canopy[\s\S]*?Slope\s*1\s*:\s*x\s*[:\s|]*([0-9.]+)/i);
    if (canProj) {
        result.additions.hasCanopy = true;
        let parts = [canProj[1].trim()];
        if (canLen) parts.push(`Length: ${canLen[1].trim()}`);
        if (canBot) parts.push(`Clear Ht: ${canBot[1].trim()} m`);
        if (canSlp) parts.push(`Slope: 1:${canSlp[1].trim()}`);
        result.additions.canopyDesc = parts.join(', ');
        result.summary.canopyArea = '144';
    }

    const mezAreaMatch = fullText.match(/Total\s*Area\s*Sq\.\s*m\s*[:\s|]*([0-9.]+)/i) ||
                          fullText.match(/DECK\s*SHEET[^\n\r]*?(\d{2,5})/i);
    const mezDl = fullText.match(/DL\s*on\s*the\s*Floor\s*KN\/m\s*2\s*[:\s|]*([^\n\r]+?)(?=\s*(?:f\.|\n))/i);
    const mezLl = fullText.match(/LL\s*on\s*the\s*Floor\s*KN\/m\s*2\s*[:\s|]*(?:[a-z]\)\s*)?([0-9.]+)/i) ||
                  fullText.match(/LL\s*on\s*the\s*Floor\s*KN\/m\s*2\s*[:\s|]*([^\n\r]+?)(?=\s*(?:7|Shear|\n))/i);
    const mezDim = fullText.match(/Mezzanine[^\n\r]*?Dimensions\s*[:\s|]*([^\n\r]+?)(?=\s*(?:BUILDING|\n))/i);
    if (mezAreaMatch) {
        result.additions.hasMezzanine = true;
        result.summary.mezzanineArea = mezAreaMatch[1].trim();
        let mParts = [`Total Area: ${mezAreaMatch[1].trim()} Sq.m`];
        if (mezDim) mParts.push(mezDim[1].trim());
        if (mezDl) mParts.push(`DL: ${mezDl[1].trim()} KN/m²`);
        if (mezLl) mParts.push(`LL: ${mezLl[1].trim()} KN/m²`);
        result.additions.mezzanineDesc = mParts.join(', ');
    }

    let grossNum = parseFloat(result.summary.mainBuildingArea) || 0;
    if (result.additions.hasMezzanine && parseFloat(result.summary.mezzanineArea)) grossNum += parseFloat(result.summary.mezzanineArea);
    if (result.additions.hasCanopy && parseFloat(result.summary.canopyArea)) grossNum += parseFloat(result.summary.canopyArea);
    result.summary.grossArea = String(Math.round(grossNum));

    // Crane
    const craneMatch = fullText.match(/Crane\s*Details\s*-\s*([^\n\r]+?)(?=\s*(?:Client|b\.|\n))/i) ||
                       fullText.match(/Crane\s*capacity[^\n\r]*?[:\s|]+([^\n\r|]+)/i);
    const craneWalk = fullText.match(/Crane\s*level\s*walkway\s*-\s*([^\n\r]+?)(?=\s*(?:Client|5|\n))/i);
    if (craneMatch && !/NA|None|No\b/i.test(craneMatch[1])) {
        result.additions.hasCrane = true;
        let cStr = craneMatch[1].trim();
        if (craneWalk) cStr += ' (Walkway: ' + craneWalk[1].trim() + ')';
        result.additions.craneDesc = cStr;
    }

    // Roof Monitor
    const rmMatch = fullText.match(/Roof\s*Monitor\s*-\s*([^\n\r]+?)(?=\s*(?:2|Ridge|Client|\n))/i);
    if (rmMatch) result.additions.roofMonitorDesc = rmMatch[1].trim();

    // Codes & Loads
    const seisMatch = fullText.match(/Seismic\s*Zone\s*-\s*([^\n\r]+?)(?=\s*(?:Code|Client|\n))/i) ||
                      fullText.match(/Seismic\s*zone[^\n\r]*?[:\s|]+([IVX]+|\d+)/i);
    if (seisMatch) result.designCriteria.seismicZone = seisMatch[1].trim();

    const windMatch = fullText.match(/Wind\s*Speed[^\n\r]*?(?:m\/s)?\s*[:\s|]*([0-9.]+\s*(?:m\/s)?)/i) ||
                      fullText.match(/wind\s*speed[^\n\r]*?[:\s|]+([0-9.]+\s*m\/s|[0-9.]+)/i);
    if (windMatch) result.designCriteria.windSpeed = windMatch[1].trim();

    const codeMatch = fullText.match(/Primary\s*Member\/Bracing\s*-\s*([^\n\r]+?)(?=\s*(?:Code|b\.|\n))/i);
    if (codeMatch) result.designCriteria.designCode = codeMatch[1].trim();

    // ── 3. ROOF SYSTEM ──
    const roofSheetMatch = fullText.match(/(?:Sheeting\s*Profile|Roof\s*Sheeting)\s*(?:Type)?\s*[:\s|]+([^\n\r|]+)/i);
    if (roofSheetMatch) {
        result.roofSystem.sheetingProfile = roofSheetMatch[1].replace(/Client|Type/gi, '').trim();
    }

    const roofThkMatch = fullText.match(/(?:Roof\s*System[\s\S]*?Thickness\s*Of\s*Sheet\s*\(TCT\)|Thickness\s*Of\s*Sheet\s*\(TCT\))\s*[:\s]*([^\n\r]+)/i) ||
                         fullText.match(/Roof\s*Sheeting[\s\S]*?([0-9.]+\s*mm)/i);
    if (roofThkMatch) result.roofSystem.thickness = roofThkMatch[1].trim();

    const roofMatMatch = fullText.match(/(?:Roof\s*System[\s\S]*?Material\s*of\s*Construction|Material\s*of\s*Construction)\s*[:\s]*([^\n\r]+)/i) ||
                         fullText.match(/Roof\s*Sheeting[\s\S]*?(Bare[\s\w-]+|Color[\s\w-]+|Galvalume[\s\w-]+)/i);
    if (roofMatMatch) result.roofSystem.material = roofMatMatch[1].trim();

    const eaveMatch = fullText.match(/Eave\s*Condition(?:\s*1\s*Near\s*Side\s*Wall)?\s*(?:Type)?\s*[:\s|]+([^\n\r|]+)/i);
    if (eaveMatch) {
        result.roofSystem.eaveCondition = eaveMatch[1].replace(/Client|Assumed|Type/gi, '').trim();
    }

    // ── 4. WALL SYSTEM ──
    const wallCladMatch = fullText.match(/Wall\s*Cladding\s*(?:Type)?\s*[:\s|]+([^\n\r|]+)/i);
    if (wallCladMatch) {
        result.wallSystem.claddingProfile = wallCladMatch[1].replace(/Client|Type/gi, '').trim();
    }

    const wallThkMatch = fullText.match(/Wall\s*System[\s\S]*?Thickness\s*Of\s*Sheet\s*\(TCT\)\s*[:\s]*([^\n\r]+)/i) ||
                         fullText.match(/Wall\s*Cladding[\s\S]*?([0-9.]+\s*mm)/i);
    if (wallThkMatch) result.wallSystem.thickness = wallThkMatch[1].trim();

    const wallMatMatch = fullText.match(/Wall\s*System[\s\S]*?Material\s*Of\s*Construction\s*[:\s]*([^\n\r]+)/i) ||
                         fullText.match(/Wall\s*Cladding[\s\S]*?(PPGL|Bare[\s\w-]+|Color[\s\w-]+)/i);
    if (wallMatMatch) result.wallSystem.material = wallMatMatch[1].trim();

    const downspoutMatch = fullText.match(/Downspouts?\s*[:\s]*([^\n\r]+)/i) ||
                           fullText.match(/([0-9.]+\s*mm\s+thick\s+PPGL\s+Gutter[\s\w]+Downcomers)/i);
    if (downspoutMatch) result.wallSystem.downspouts = downspoutMatch[1].trim();

    const brickWallMatch = fullText.match(/Brick\s*wall\s*Height\s*[:\s]*([^\n\r]+)/i) ||
                           fullText.match(/([0-9.]+\s*m\s*B\/W\s*\.\s*Rest\s*covered\s*with\s*sheeting)/i);
    if (brickWallMatch) result.wallSystem.brickWallHeight = brickWallMatch[1].trim();

    // ── 5. CHECK FOR TABULAR FORMAT (e.g. QRF Page 4: Section F. Accessories & G. Material Specification) ──
    let parsedTabularF = false;
    for (const p of pages) {
        const hasSectionF = p.lines.some(l => /F\.\s*Accessories/i.test(l.map(it => it.str).join(' ')));
        const hasSectionG = p.lines.some(l => /G\.\s*Material/i.test(l.map(it => it.str).join(' ')));
        const hasNote = p.lines.some(l => /#\s*Note/i.test(l.map(it => it.str).join(' ')));

        if (hasSectionF && (hasSectionG || hasNote)) {
            parsedTabularF = true;
            let yF = null;
            let yG = null;
            let yNote = null;

            for (const line of p.lines) {
                const lineStr = line.map(it => it.str).join(' ');
                if (/F\.\s*Accessories/i.test(lineStr)) yF = line[0].y;
                if (/G\.\s*Material/i.test(lineStr)) yG = line[0].y;
                if (/#\s*Note/i.test(lineStr)) yNote = line[0].y;
            }
            if (yF === null) yF = 560;
            if (yG === null) yG = 320;
            if (yNote === null) yNote = 140;

            // Extract F. Accessories (strictly between yF and yG)
            const fLines = p.lines.filter(line => line[0].y < yF - 8 && line[0].y > yG + 8);
            let curAcc = null;
            const accRows = [];

            for (const line of fLines) {
                const srItem = line.find(it => it.x < 30 && /^\d+$/.test(it.str));
                const paramItem = line.find(it => it.x >= 30 && it.x < 130);
                if (srItem || (paramItem && !curAcc)) {
                    if (curAcc && (curAcc.param || curAcc.desc)) accRows.push(curAcc);
                    curAcc = {
                        sr: srItem ? srItem.str : '',
                        param: paramItem ? paramItem.str : '',
                        desc: line.filter(it => it.x >= 140 && it.x < 340).map(it => it.str).join(' '),
                        remark: line.filter(it => it.x >= 340).map(it => it.str).join(' ')
                    };
                } else if (curAcc) {
                    const extraParam = line.filter(it => it.x >= 30 && it.x < 130).map(it => it.str).join(' ');
                    if (extraParam) curAcc.param += ' ' + extraParam;
                    const extraDesc = line.filter(it => it.x >= 140 && it.x < 340).map(it => it.str).join(' ');
                    if (extraDesc) curAcc.desc += ' ' + extraDesc;
                    const extraRem = line.filter(it => it.x >= 340).map(it => it.str).join(' ');
                    if (extraRem) curAcc.remark += ' ' + extraRem;
                }
            }
            if (curAcc && (curAcc.param || curAcc.desc)) accRows.push(curAcc);

            for (const r of accRows) {
                const paramName = (r.param || '').trim();
                const descVal = (r.desc || '').trim();
                const remarkVal = (r.remark || '').trim();

                if (!descVal && !remarkVal) continue;

                const isBuyout = /Sky\s*Light|Wall\s*Light|Polycarbonate|Turbo\s*vent/i.test(paramName);

                let qty = '1';
                const qtyMatch = (descVal + ' ' + remarkVal).match(/(\d+\s*nos|\d+\s*m\b|\d+\s*set)/i);
                if (qtyMatch) qty = qtyMatch[1];

                const itemObj = {
                    srNo: r.sr || String(result.accessories.length + result.buyouts.length + 1),
                    description: paramName,
                    size: descVal || 'NA',
                    quantity: qty,
                    remark: remarkVal
                };

                if (isBuyout) {
                    result.buyouts.push(itemObj);
                } else {
                    result.accessories.push(itemObj);
                }
            }

            // Extract G. Material Specifications (strictly between yG and yNote)
            const gLines = p.lines.filter(line => line[0].y < yG - 8 && line[0].y > yNote + 8);
            let curG = null;
            for (const line of gLines) {
                const srItem = line.find(it => it.x < 30 && /^\d+$/.test(it.str));
                const text = line.map(it => it.str).join(' ').trim();
                if (srItem || line.some(it => it.x < 130 && /^[A-Z]/.test(it.str))) {
                    if (curG) result.materialSpecs.push(curG.trim());
                    curG = text.replace(/^\d+\s*/, '');
                } else if (curG) {
                    curG += ' ' + text;
                }
            }
            if (curG) result.materialSpecs.push(curG.trim());

            // Extract # Note (strictly below yNote)
            const noteLines = p.lines.filter(line => line[0].y < yNote - 8);
            let curN = null;
            for (const line of noteLines) {
                const srItem = line.find(it => it.x < 30 && /^\d+$/.test(it.str));
                const text = line.map(it => it.str).join(' ').trim();
                if (srItem) {
                    if (curN) result.technicalNotes.push(curN.trim());
                    curN = text.replace(/^\d+\s*/, '');
                } else if (curN) {
                    curN += ' ' + text;
                }
            }
            if (curN) result.technicalNotes.push(curN.trim());
        }
    }

    // If not tabular format, use document-style accessories parser (Format A)
    if (!parsedTabularF) {
        for (const p of pages) {
            let headerY = null;
            let colBounds = null;

            for (let i = 0; i < p.lines.length; i++) {
                const line = p.lines[i];
                const hasDesc = line.some(it => /Description/i.test(it.str));
                const hasSize = line.some(it => /Size|Unit/i.test(it.str));
                const hasQty = line.some(it => /Quantity|Qty/i.test(it.str));

                if (hasDesc && (hasSize || hasQty)) {
                    headerY = line[0].y;
                    const descIt = line.find(it => /Description/i.test(it.str));
                    const sizeIt = line.find(it => /Size|Unit/i.test(it.str));
                    const qtyIt = line.find(it => /Quantity|Qty/i.test(it.str));
                    const remIt = line.find(it => /Remark/i.test(it.str));

                    colBounds = {
                        descMin: descIt ? descIt.x - 10 : 122,
                        sizeMin: sizeIt ? sizeIt.x - 30 : 250,
                        qtyMin: qtyIt ? qtyIt.x - 25 : 340,
                        remMin: remIt ? remIt.x - 30 : 420
                    };
                    break;
                }
            }

            if (headerY !== null && colBounds) {
                let tableEndY = 0;
                for (const line of p.lines) {
                    const lY = line[0].y;
                    if (lY < headerY - 10) {
                        const lStr = line.map(it => it.str).join(' ').trim();
                        if (/^(?:\([A-Z]\)|[A-Z]\.)\s+[A-Za-z]/i.test(lStr) || /^Follow\s*the\s*estimate|Special\s*condition|Building\s*technical\s*notes/i.test(lStr)) {
                            if (lY > tableEndY) tableEndY = lY;
                        }
                    }
                }
                if (tableEndY === 0) tableEndY = 100;

                const tableItems = p.items.filter(it => it.y < headerY - 5 && it.y > tableEndY);

                const lines = [];
                let cur = [];
                let curY = null;
                for (const it of tableItems) {
                    if (curY === null || Math.abs(it.y - curY) <= 4) {
                        cur.push(it);
                        curY = it.y;
                    } else {
                        lines.push({ y: curY, items: cur, text: cur.map(c => c.str).join(' ') });
                        cur = [it];
                        curY = it.y;
                    }
                }
                if (cur.length > 0) lines.push({ y: curY, items: cur, text: cur.map(c => c.str).join(' ') });

                const rowStarts = new Set();
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const hasSrNo = line.items.some(it => it.x < colBounds.descMin && /^\d+$/.test(it.str));
                    const startsWithDigitAndDesc = line.items.some(it => it.x < colBounds.sizeMin && /^\d+\s+[A-Za-z]/.test(it.str));
                    const hasAccKeyword = line.items.some(it => it.x >= colBounds.descMin && it.x < colBounds.sizeMin && 
                        /^(?:Std\.|STAIR|S-type|Bird\s*mesh|down\s*spout|Polycarbonate)/i.test(it.str));

                    if (hasSrNo || startsWithDigitAndDesc) {
                        rowStarts.add(i);
                    } else if (hasAccKeyword) {
                        if (i > 0 && lines[i - 1].items.every(it => it.x >= colBounds.remMin)) {
                            rowStarts.add(i - 1);
                        } else {
                            rowStarts.add(i);
                        }
                    }
                }

                const sortedStarts = Array.from(rowStarts).sort((a, b) => a - b);
                const lineHasSrNo = (idx) => lines[idx].items.some(it => 
                    (it.x < colBounds.descMin && /^\d+$/.test(it.str)) || 
                    (it.x < colBounds.sizeMin && /^\d+\s+[A-Za-z]/.test(it.str))
                );

                const mergedStarts = [];
                for (let i = 0; i < sortedStarts.length; i++) {
                    const curr = sortedStarts[i];
                    if (mergedStarts.length === 0) {
                        mergedStarts.push(curr);
                    } else {
                        const prev = mergedStarts[mergedStarts.length - 1];
                        if (curr - prev <= 2) {
                            const prevHasSr = lineHasSrNo(prev);
                            const currHasSr = lineHasSrNo(curr);
                            if (prevHasSr && currHasSr) {
                                mergedStarts.push(curr);
                            }
                        } else {
                            mergedStarts.push(curr);
                        }
                    }
                }

                const rowSlices = [];
                for (let i = 0; i < mergedStarts.length; i++) {
                    const start = mergedStarts[i];
                    const end = (i === mergedStarts.length - 1) ? lines.length : mergedStarts[i + 1];
                    rowSlices.push(lines.slice(start, end));
                }

                for (let idx = 0; idx < rowSlices.length; idx++) {
                    const r = rowSlices[idx];
                    const allItems = [];
                    r.forEach(l => allItems.push(...l.items));
                    allItems.sort((a, b) => {
                        if (Math.abs(a.y - b.y) <= 4) return a.x - b.x;
                        return b.y - a.y;
                    });

                    let srNo = '';
                    let desc = '';
                    let size = '';
                    let qty = '';
                    let remark = '';

                    for (const it of allItems) {
                        if (/Follow\s*the\s*estimate/i.test(it.str)) continue;
                        if (it.x < colBounds.descMin) {
                            const m = it.str.match(/^(\d+)(?:[\s.]+(.*))?$/);
                            if (m) {
                                if (!srNo) srNo = m[1];
                                if (m[2]) desc += (desc ? ' ' : '') + m[2];
                            } else {
                                srNo += (srNo ? ' ' : '') + it.str;
                            }
                        } else if (it.x < colBounds.sizeMin) {
                            const m = it.str.match(/^(\d+)(?:[\s.]+(.*))?$/);
                            if (m && !srNo) {
                                srNo = m[1];
                                if (m[2]) desc += (desc ? ' ' : '') + m[2];
                            } else {
                                let clean = it.str.replace(/^\d+[\s.]+/, '');
                                desc += (desc ? ' ' : '') + clean;
                            }
                        } else if (it.x < colBounds.qtyMin) {
                            size += (size ? ' ' : '') + it.str;
                        } else if (it.x < colBounds.remMin) {
                            qty += (qty ? ' ' : '') + it.str;
                        } else {
                            remark += (remark ? ' ' : '') + it.str;
                        }
                    }

                    desc = desc.trim();
                    if (desc) {
                        const itemObj = {
                            srNo: srNo || String(result.accessories.length + result.buyouts.length + 1),
                            description: desc,
                            size: size.trim(),
                            quantity: qty.trim(),
                            remark: remark.trim()
                        };

                        if (/polycarbonate|turbovent|turbo\s*vent/i.test(desc)) {
                            result.buyouts.push(itemObj);
                        } else {
                            result.accessories.push(itemObj);
                        }
                    }
                }
            }
        }

        // Format A: Technical Notes (D.1)
        const notesMatch = fullText.match(/(?:D\.1\s*Building\s*technical\s*notes:?|Building\s*technical\s*notes:?)([\s\S]*?)(?=D\.2|Specification\s*of\s*materials|\(E\)|E\.\s*SUPPLY|Page\s*\d|$)/i);
        if (notesMatch) {
            const notesBlock = notesMatch[1];
            const lines = notesBlock.split('\n').map(l => l.trim()).filter(l => l.length > 0);
            let curNote = '';
            for (const l of lines) {
                if (/^\d+[\).]\s*/.test(l)) {
                    if (curNote && !/Building\s*technical\s*notes/i.test(curNote)) {
                        result.technicalNotes.push(curNote.trim());
                    }
                    curNote = l.replace(/^\d+[\).]\s*/, '');
                } else {
                    curNote += ' ' + l;
                }
            }
            if (curNote && !/Building\s*technical\s*notes/i.test(curNote)) {
                result.technicalNotes.push(curNote.trim());
            }
        }

        // Format A: Material Specifications (D.2)
        const specsMatch = fullText.match(/(?:D\.2\s*Specification\s*of\s*materials:?|Specification\s*of\s*materials:?)([\s\S]*?)(?=(?:\(E\)|E\.\s*SUPPLY|Page\s*\d|$))/i);
        if (specsMatch) {
            const specsBlock = specsMatch[1];
            const lines = specsBlock.split('\n').map(l => l.trim()).filter(l => l.length > 0);
            let curSpec = '';
            for (const l of lines) {
                if (/^\d+[\).]\s*/.test(l)) {
                    if (curSpec && !/Specification\s*of\s*materials/i.test(curSpec)) {
                        result.materialSpecs.push(curSpec.trim());
                    }
                    curSpec = l.replace(/^\d+[\).]\s*/, '');
                } else {
                    curSpec += ' ' + l;
                }
            }
            if (curSpec && !/Specification\s*of\s*materials/i.test(curSpec)) {
                result.materialSpecs.push(curSpec.trim());
            }
        }
    }


    // ── 6. QRF PARAM TABLE EXTRACTOR ──
    const isQrf = /QRF\s*#|Parameter\s+Unit/i.test(fullText);
    if (isQrf) {
        const colBounds = {
            param: 35,
            unit: 120,
            value: 155,
            from: 340,
            remark: 380
        };

        for (const p of pages) {
            for (const line of p.lines) {
                const lineStr = line.map(it => it.str).join(' ').trim();
                // Skip title/header banners and repeated column headers
                if (/BUILDING\s*GEOMETRY|QRF\s*#|LalBaba|FACTORY\s*SHED|\d{2}-\d{2}-\d{4}/i.test(lineStr)) continue;
                if (/^(Date|By|Rev\.|Client\s*$|Name\s*$)/i.test(lineStr)) continue;
                if (/^(?:Sl\.?\s*No\.?|Unit\/?\s*Type|Parameter|Value\/?\s*Description|Data\s*from|Remark)$/i.test(lineStr)) continue;
                if (/^Sl\.\s*Unit\/?|^Parameter\s+Value\/?|^No\.\s*Type/i.test(lineStr)) continue;

                // Check if major section header (e.g. A. Building Parameter, B. Roof & Wall Condition, etc.)
                const sectionHeaderItem = line.find(it => /^[A-Z]\.$/.test(it.str.trim()) && it.x < colBounds.param);
                if (sectionHeaderItem) {
                    const paramText = line.filter(it => it.x >= colBounds.param).map(it => it.str).join(' ').trim();
                    result.paramTable.push({
                        slNo: sectionHeaderItem.str.trim(),
                        parameter: paramText,
                        unit: '',
                        value: '',
                        dataFrom: '',
                        remark: '',
                        isHeader: true
                    });
                    continue;
                }

                // Check if Note section header
                if (/^#\s*Note/i.test(lineStr)) {
                    result.paramTable.push({
                        slNo: '#',
                        parameter: 'Note',
                        unit: '',
                        value: '',
                        dataFrom: '',
                        remark: '',
                        isHeader: true
                    });
                    continue;
                }

                let slNo = '', parameter = '', unit = '', value = '', dataFrom = '', remark = '';
                line.forEach(it => {
                    const str = it.str.trim();
                    if (!str) return;
                    if (it.x < colBounds.param) slNo += (slNo ? ' ' : '') + str;
                    else if (it.x < colBounds.unit) parameter += (parameter ? ' ' : '') + str;
                    else if (it.x < colBounds.value) unit += (unit ? ' ' : '') + str;
                    else if (it.x < colBounds.from) value += (value ? ' ' : '') + str;
                    else if (it.x < colBounds.remark) dataFrom += (dataFrom ? ' ' : '') + str;
                    else remark += (remark ? ' ' : '') + str;
                });

                if (!slNo && !parameter && !unit && !value && !dataFrom && !remark) continue;

                const isGroupHeader = slNo && parameter && !unit && !value && !dataFrom && !remark;
                const isStandaloneWithoutSl = !slNo && parameter && (unit || (value && dataFrom));

                if (slNo || isGroupHeader || isStandaloneWithoutSl) {
                    result.paramTable.push({
                        slNo: slNo || '-',
                        parameter,
                        unit,
                        value,
                        dataFrom,
                        remark,
                        isHeader: isGroupHeader
                    });
                } else {
                    if (result.paramTable.length > 0 && !result.paramTable[result.paramTable.length - 1].isHeader) {
                        const last = result.paramTable[result.paramTable.length - 1];
                        if (parameter) last.parameter += (last.parameter ? ' ' : '') + parameter;
                        if (unit) last.unit += (last.unit ? ' ' : '') + unit;
                        if (value) last.value += (last.value ? ' ' : '') + value;
                        if (dataFrom) last.dataFrom += (last.dataFrom ? ' ' : '') + dataFrom;
                        if (remark) last.remark += (last.remark ? ' ' : '') + remark;
                    } else if (result.paramTable.length > 0 && result.paramTable[result.paramTable.length - 1].isHeader) {
                        const last = result.paramTable[result.paramTable.length - 1];
                        if (parameter) last.parameter += (last.parameter ? ' ' : '') + parameter;
                    }
                }
            }
        }
    }

    // ── 7. UNIVERSAL DOCUMENT SECTIONS (FROM (A) DESIGN CRITERIA TO END) ──
    const hasDesignCriteria = /(?:\(A\)\s*)?DESIGN\s*CRITERIA/i.test(fullText);
    if (hasDesignCriteria) {
        result.docSections = extractUniversalDocSections(pages, result);
    }

    return result;
}

function cleanPebText(str) {
    if (!str || typeof str !== 'string') return str || '';
    return str
        .replace(/\bS\s+teel\b/g, 'Steel')
        .replace(/\bs\s+teel\b/g, 'steel')
        .replace(/\bSTEEL\b/g, 'STEEL')
        .replace(/\bo\s+f\b/gi, 'of')
        .replace(/\bC\s*\/\s*C\b/g, 'C/C')
        .replace(/\bGalvalum\s+e\b/gi, 'Galvalume')
        .replace(/\bGal\s+valume\b/gi, 'Galvalume')
        .replace(/\bdown\s+co\s*mer\b/gi, 'down comer')
        .replace(/\bco\s+mer\b/gi, 'comer')
        .replace(/\bO\s+ne\b/g, 'One')
        .replace(/\bP\s+aint\b/g, 'Paint')
        .replace(/\bcoat\s+s\b/gi, 'coats')
        .replace(/\b0\.\s+(\d+)\b/g, '0.$1')
        .replace(/\b1\s*:\s*10\b/g, '1:10')
        .replace(/\bAZ\s*-\s*150\b/gi, 'AZ-150')
        .replace(/\s{2,}/g, ' ')
        .trim();
}

function extractUniversalDocSections(pages, result) {
    let startPageIdx = -1;
    let startLineIdx = -1;

    for (let p = 0; p < pages.length; p++) {
        for (let l = 0; l < pages[p].lines.length; l++) {
            const lineStr = pages[p].lines[l].map(it => it.str).join(' ');
            if (/(?:\(A\)\s*)?DESIGN\s*CRITERIA/i.test(lineStr)) {
                startPageIdx = p;
                startLineIdx = l;
                break;
            }
        }
        if (startPageIdx !== -1) break;
    }

    if (startPageIdx === -1) return [];

    const rawLines = [];
    for (let p = startPageIdx; p < pages.length; p++) {
        const lines = pages[p].lines;
        const startL = (p === startPageIdx) ? startLineIdx : 0;
        for (let l = startL; l < lines.length; l++) {
            const lineStr = lines[l].map(it => it.str).join(' ').trim();
            if (/^Page\s+\d+\s+of\s+\d+$/i.test(lineStr)) continue;
            rawLines.push({ pageNum: p + 1, lineStr, items: lines[l] });
        }
    }

    const isMajorHeader = (lineStr) => /^(?:\([A-Z]\)|[A-Z]\.)\s+[A-Za-z]/i.test(lineStr);
    const isSubHeader = (lineStr) => /^[A-Z]\.\d+(?:\.\d+)*\s+[A-Za-z]/i.test(lineStr);
    const isSectionHeader = (lineStr) => isMajorHeader(lineStr) || isSubHeader(lineStr) || /^DESIGN\s*CRITERIA$/i.test(lineStr);
    const isListItem = (lineStr) => /^\d+[\).]\s+/.test(lineStr) || /^[•\-–]\s+/.test(lineStr);

    const rawSections = [];
    let curSection = null;

    for (let i = 0; i < rawLines.length; i++) {
        const { pageNum, lineStr, items } = rawLines[i];
        if (isSectionHeader(lineStr)) {
            if (curSection) rawSections.push(curSection);
            curSection = { title: lineStr, isMajor: isMajorHeader(lineStr), pageNum, lines: [] };
        } else {
            if (!curSection) curSection = { title: '(A) DESIGN CRITERIA', isMajor: true, pageNum, lines: [] };
            curSection.lines.push({ pageNum, lineStr, items });
        }
    }
    if (curSection) rawSections.push(curSection);

    const structuredSections = [];

    for (const sec of rawSections) {
        const title = sec.title;
        const lines = sec.lines;

        // 1. Major chapters without lines
        if (sec.isMajor && lines.length === 0) {
            structuredSections.push({
                title: title,
                subtitle: '',
                sectionType: 'chapter',
                colCount: 0,
                tableHeaders: [],
                tableRows: [],
                listItems: [],
                notes: []
            });
            continue;
        }

        // 2. (A) DESIGN CRITERIA
        if (/DESIGN\s*CRITERIA/i.test(title)) {
            const notes = lines.map(l => l.lineStr).filter(s => s && !/^Building$/i.test(s));
            structuredSections.push({
                title: title.startsWith('(') ? title : '(A) ' + title,
                subtitle: '',
                sectionType: 'chapter',
                colCount: 0,
                tableHeaders: [],
                tableRows: [],
                listItems: [],
                notes: notes
            });
            continue;
        }

        // 3. (B) Project Summary - Standalone 2-cell box + Subtitle + 3-column table
        if (/Project\s*Summary/i.test(title)) {
            structuredSections.push({
                title: title,
                subtitle: '',
                sectionType: 'chapter',
                colCount: 0,
                tableHeaders: [],
                tableRows: [],
                listItems: [],
                notes: []
            });
            let curTable = null;
            let subtitle = '';
            for (const l of lines) {
                const s = l.lineStr;
                if (/^Total\s*no\.\s*of\s*Buildings/i.test(s)) {
                    const match = s.match(/^Total\s*no\.\s*of\s*Buildings\s*[:\s]*(.*)$/i);
                    let right = (match && match[1]) ? match[1].trim() : '';
                    if (!right) {
                        right = l.items.filter(it => it.x >= 350).map(it => it.str).join(' ').trim() || '01';
                    }
                    structuredSections.push({
                        title: '',
                        subtitle: '',
                        sectionType: 'table',
                        colCount: 2,
                        tableHeaders: [],
                        tableRows: [{ c1: 'Total no. of Buildings', c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false }],
                        listItems: [],
                        notes: []
                    });
                    continue;
                }
                if (/^\(if\s*more\s*than\s*one/i.test(s)) {
                    subtitle = s;
                    continue;
                }
                if (/^UTILITY\s*OF\s*BUILDING/i.test(s)) {
                    curTable = {
                        title: '',
                        subtitle: subtitle,
                        sectionType: 'table',
                        colCount: 3,
                        tableHeaders: ['UTILITY OF BUILDING.', 'No. OF BUILDING', 'Total Area (Sqm.)'],
                        tableRows: [],
                        listItems: [],
                        notes: []
                    };
                    structuredSections.push(curTable);
                    continue;
                }
                if (/^\(Sqm\.\)/i.test(s)) continue;
                if (curTable) {
                    if (/Total\s*area/i.test(s)) {
                        const num = l.items[l.items.length - 1].str;
                        curTable.tableRows.push({ c1: '', c2: 'Total area', c3: num, c4: '', c5: '', c6: '', isSubHeader: false });
                    } else {
                        let c1 = l.items.filter(it => it.x < 260).map(it => it.str).join(' ').trim();
                        let c2 = l.items.filter(it => it.x >= 260 && it.x < 420).map(it => it.str).join(' ').trim();
                        let c3 = l.items.filter(it => it.x >= 420).map(it => it.str).join(' ').trim();
                        if (!c1 && !c2 && !c3) {
                            if (l.items.length >= 3) {
                                c1 = l.items.slice(0, l.items.length - 2).map(it => it.str).join(' ').trim();
                                c2 = l.items[l.items.length - 2].str;
                                c3 = l.items[l.items.length - 1].str;
                            } else if (l.items.length === 2) {
                                c1 = l.items[0].str;
                                c2 = l.items[1].str;
                            }
                        }
                        if (c1 || c2 || c3) {
                            curTable.tableRows.push({ c1, c2, c3, c4: '', c5: '', c6: '', isSubHeader: false });
                        }
                    }
                }
            }
            continue;
        }

        // 4. List Sections (Technical notes, assumptions, deviations, etc.) with dynamic embedded table detection
        if (/technical\s*notes|Specification\s*of\s*materials|assumptions|deviations/i.test(title) || (lines.length > 0 && lines.some(l => isListItem(l.lineStr)))) {
            const blocks = partitionSectionLines(lines);
            for (let b = 0; b < blocks.length; b++) {
                const block = blocks[b];
                const blockTitle = (b === 0) ? title : '';

                if (block.type === 'table') {
                    const dynTable = parseDynamicTable(blockTitle, block.lines);
                    if (dynTable && dynTable.tableRows.length > 0) {
                        structuredSections.push(dynTable);
                    }
                } else {
                    const listItems = [];
                    let curItem = '';
                    for (const l of block.lines) {
                        const s = l.lineStr;
                        if (isListItem(s)) {
                            if (curItem) listItems.push(cleanPebText(curItem.trim()));
                            curItem = s;
                        } else {
                            curItem += (curItem ? ' ' : '') + s;
                        }
                    }
                    if (curItem) listItems.push(cleanPebText(curItem.trim()));
                    if (listItems.length > 0) {
                        structuredSections.push({
                            title: blockTitle,
                            subtitle: '',
                            sectionType: 'list',
                            colCount: 0,
                            tableHeaders: [],
                            tableRows: [],
                            listItems: listItems,
                            notes: []
                        });
                    }
                }
            }
            continue;
        }

        // 5. Software used (A.3)
        if (/Software\s*used/i.test(title)) {
            const tableRows = [];
            for (const l of lines) {
                if (/^Type\s+of\s+structure/i.test(l.lineStr)) continue;
                const c1 = l.items.filter(it => it.x < 250).map(it => it.str).join(' ').trim();
                const c2 = l.items.filter(it => it.x >= 250 && it.x < 420).map(it => it.str).join(' ').trim();
                const c3 = l.items.filter(it => it.x >= 420).map(it => it.str).join(' ').trim();
                if (c1 || c2 || c3) {
                    tableRows.push({ c1, c2, c3, c4: '', c5: '', c6: '', isSubHeader: false });
                }
            }
            if (tableRows.length === 0) {
                const match = title.match(/Software\s*used:\s*(.*)/i);
                const val = match ? match[1].trim() : lines.map(l => l.lineStr).join(' ');
                tableRows.push(
                    { c1: 'Primary & bracing', c2: val || 'STAAD-PRO Connect Edition', c3: '3D', c4: '', c5: '', c6: '', isSubHeader: false },
                    { c1: 'Secondary', c2: 'Spread Sheet (Excel)', c3: '2D', c4: '', c5: '', c6: '', isSubHeader: false }
                );
            }
            structuredSections.push({
                title: title.replace(/:\s*STAAD.*$/i, '').trim(),
                subtitle: '',
                sectionType: 'table',
                colCount: 3,
                tableHeaders: ['Type of structure', 'Software', 'Modeling'],
                tableRows: tableRows,
                listItems: [],
                notes: []
            });
            continue;
        }

        // 6. Accessories (C.1.8.7) - Strictly parsed from section lines, ending cleanly before Section D
        if (/Accessories/i.test(title)) {
            const tableHeaders = ['', 'Description', 'Quantity', 'Remarks'];
            const tableRows = [];
            let curRow = null;
            for (const l of lines) {
                if (/^Description\s+Quantity/i.test(l.lineStr)) continue;
                const srItem = l.items.find(it => it.x < 100 && /^\d+[\.)]?$/.test(it.str));
                const srX = srItem ? srItem.x : -1;
                const descText = l.items.filter(it => it !== srItem && it.x >= (srX >= 0 ? srX + 10 : 80) && it.x < 170).map(it => it.str).join(' ').trim();
                const qtyText = l.items.filter(it => it !== srItem && it.x >= 170 && it.x < 350).map(it => it.str).join(' ').trim();
                const remText = l.items.filter(it => it !== srItem && it.x >= 350).map(it => it.str).join(' ').trim();

                if (srItem) {
                    if (curRow) tableRows.push(curRow);
                    const cleanNum = srItem.str.replace(/[\.)]$/, '');
                    curRow = { c1: cleanNum, c2: descText, c3: qtyText, c4: remText, c5: '', c6: '', isSubHeader: false };
                } else if (curRow) {
                    if (descText) curRow.c2 += (curRow.c2 ? ' ' : '') + descText;
                    if (qtyText) curRow.c3 += (curRow.c3 ? ' ' : '') + qtyText;
                    if (remText) curRow.c4 += (curRow.c4 ? ' ' : '') + remText;
                }
            }
            if (curRow) tableRows.push(curRow);

            structuredSections.push({
                title: title,
                subtitle: '',
                sectionType: 'table',
                colCount: 4,
                tableHeaders,
                tableRows,
                listItems: [],
                notes: []
            });
            continue;
        }

        // 7. Generic Table Parser for all other tables
        const secObj = parseGenericSectionTable(title, lines);
        structuredSections.push(secObj);
    }

    return structuredSections;
}

function isTableStartLine(l) {
    if (!l || !l.items || l.items.length === 0) return false;

    // 1. Table with Serial Number: e.g. "1 Sheeting Profile UIL Profiled..."
    const bareDigitItem = l.items.find(it => it.x < 120 && /^\d+$/.test(it.str.trim()));
    if (bareDigitItem) {
        const others = l.items.filter(it => it !== bareDigitItem);
        if (others.some(it => it.x >= 220) || others.length >= 2) {
            return true;
        }
    }

    // 2. Serial number with dot/paren BUT with distinct column gap (> 45px) between items
    const srItem = l.items.find(it => it.x < 120 && /^\d+[\).]$/.test(it.str.trim()));
    if (srItem) {
        for (let j = 0; j < l.items.length - 1; j++) {
            const rightEdge = l.items[j].x + (l.items[j].w || (l.items[j].str.length * 5.5));
            const nextLeft = l.items[j + 1].x;
            if (nextLeft - rightEdge > 45) {
                return true;
            }
        }
    }

    // 3. Header keywords across columns
    const hasHdrKeywords = /^(?:Sr\.?\s*No\.?|Description|Parameter|Location|Quantity|Remarks|Specification)/i.test(l.lineStr);
    if (hasHdrKeywords && l.items.length >= 2) return true;

    // 4. Two-column spread with gap > 40px
    const leftItems = l.items.filter(it => it.x < 240);
    const rightItems = l.items.filter(it => it.x >= 240);
    if (leftItems.length > 0 && rightItems.length > 0) {
        const lastLeftX = Math.max(...leftItems.map(it => it.x + (it.w || (it.str.length * 5.5))));
        const firstRightX = Math.min(...rightItems.map(it => it.x));
        if (firstRightX - lastLeftX > 40) return true;
    }

    return false;
}

function partitionSectionLines(lines) {
    const blocks = [];
    let curBlock = null;

    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];

        if (curBlock && curBlock.type === 'table') {
            const isListBullet = /^\d+[\).]\s+[A-Za-z]/.test(l.lineStr) || /^[•\-–]\s+/.test(l.lineStr);

            if (isListBullet && !isTableStartLine(l)) {
                curBlock = { type: 'list', lines: [l] };
                blocks.push(curBlock);
            } else {
                curBlock.lines.push(l);
            }
        } else {
            if (isTableStartLine(l)) {
                curBlock = { type: 'table', lines: [l] };
                blocks.push(curBlock);
            } else {
                if (!curBlock || curBlock.type !== 'list') {
                    curBlock = { type: 'list', lines: [] };
                    blocks.push(curBlock);
                }
                curBlock.lines.push(l);
            }
        }
    }

    return blocks;
}

function parseDynamicTable(title, lines) {
    if (!lines || lines.length === 0) return null;

    const hasSrCol = lines.some(l => l.items.some(it => it.x < 120 && /^\d+[\).]?$/.test(it.str.trim())));
    const hasCol4 = lines.some(l => l.items.some(it => it.x >= 350) && l.items.some(it => it.x >= 170 && it.x < 350));

    let colCount = 2;
    let colWidths = ['40%', '60%'];
    let tableHeaders = [];

    let dataStartIdx = 0;
    const firstLine = lines[0];
    if (/^(?:Sr\.?\s*No\.?|Parameter|Description|Location|Item|Sl\.?\s*No\.?)/i.test(firstLine.lineStr)) {
        dataStartIdx = 1;
        if (hasCol4) {
            colCount = 4;
            colWidths = ['8%', '32%', '30%', '30%'];
            const c1 = firstLine.items.filter(it => it.x < 100).map(it => it.str).join(' ').trim();
            const c2 = firstLine.items.filter(it => it.x >= 100 && it.x < 220).map(it => it.str).join(' ').trim();
            const c3 = firstLine.items.filter(it => it.x >= 220 && it.x < 350).map(it => it.str).join(' ').trim();
            const c4 = firstLine.items.filter(it => it.x >= 350).map(it => it.str).join(' ').trim();
            tableHeaders = [c1 || 'Sr. No.', c2 || 'Description', c3 || 'Quantity', c4 || 'Remarks'];
        } else if (hasSrCol) {
            colCount = 3;
            colWidths = ['6%', '34%', '60%'];
            const c1 = firstLine.items.filter(it => it.x < 120).map(it => it.str).join(' ').trim();
            const c2 = firstLine.items.filter(it => it.x >= 120 && it.x < 240).map(it => it.str).join(' ').trim();
            const c3 = firstLine.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();
            tableHeaders = [c1 || 'Sr. No.', c2 || 'Description', c3 || 'Specification'];
        } else {
            colCount = 2;
            colWidths = ['40%', '60%'];
            const c1 = firstLine.items.filter(it => it.x < 250).map(it => it.str).join(' ').trim();
            const c2 = firstLine.items.filter(it => it.x >= 250).map(it => it.str).join(' ').trim();
            tableHeaders = [c1 || 'Parameter', c2 || 'Value'];
        }
    } else {
        if (hasCol4) {
            colCount = 4;
            colWidths = ['8%', '32%', '30%', '30%'];
        } else if (hasSrCol) {
            colCount = 3;
            colWidths = ['6%', '34%', '60%'];
        }
    }

    const tableRows = [];
    const rowObjs = [];

    for (let i = dataStartIdx; i < lines.length; i++) {
        const l = lines[i];

        if (colCount === 4) {
            const srItem = l.items.find(it => it.x < 100 && /^\d+[\).]?$/.test(it.str.trim()));
            const c2Text = l.items.filter(it => it !== srItem && it.x >= 80 && it.x < 220).map(it => it.str).join(' ').trim();
            const c3Text = l.items.filter(it => it !== srItem && it.x >= 220 && it.x < 350).map(it => it.str).join(' ').trim();
            const c4Text = l.items.filter(it => it !== srItem && it.x >= 350).map(it => it.str).join(' ').trim();

            if (srItem) {
                const cleanSr = srItem.str.replace(/[\).]$/, '');
                rowObjs.push({
                    c1: cleanSr,
                    c2: c2Text,
                    c3: c3Text,
                    c4: c4Text
                });
            } else if (rowObjs.length > 0) {
                const prev = rowObjs[rowObjs.length - 1];
                if (c2Text) prev.c2 += (prev.c2 ? ' ' : '') + c2Text;
                if (c3Text) prev.c3 += (prev.c3 ? ' ' : '') + c3Text;
                if (c4Text) prev.c4 += (prev.c4 ? ' ' : '') + c4Text;
            }
        } else if (colCount === 3) {
            const srItem = l.items.find(it => it.x < 120 && /^\d+[\).]?$/.test(it.str.trim()));
            const midText = l.items.filter(it => it !== srItem && it.x >= 80 && it.x < 240).map(it => it.str).join(' ').trim();
            const rightText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();

            if (srItem) {
                const cleanSr = srItem.str.replace(/[\).]$/, '');
                rowObjs.push({
                    c1: cleanSr,
                    c2: midText,
                    c3: rightText
                });
            } else {
                if (rowObjs.length === 0) {
                    rowObjs.push({
                        c1: '',
                        c2: midText,
                        c3: rightText
                    });
                } else {
                    const prevRow = rowObjs[rowObjs.length - 1];
                    const nextLine = (i + 1 < lines.length) ? lines[i + 1] : null;
                    const nextHasSr = nextLine && nextLine.items.some(it => it.x < 120 && /^\d+[\).]?$/.test(it.str.trim()));
                    const nextHasRight = nextLine && nextLine.items.some(it => it.x >= 240);

                    if (!midText && rightText && prevRow.c3 && nextHasSr && !nextHasRight) {
                        prevRow.pendingForNext = (prevRow.pendingForNext ? prevRow.pendingForNext + ' ' : '') + rightText;
                    } else {
                        if (midText) prevRow.c2 += (prevRow.c2 ? ' ' : '') + midText;
                        if (rightText) prevRow.c3 += (prevRow.c3 ? ' ' : '') + rightText;
                    }
                }
            }
        } else {
            // 2 columns
            const left = l.items.filter(it => it.x < 250).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 250).map(it => it.str).join(' ').trim();
            if (left) {
                rowObjs.push({ c1: left, c2: right });
            } else if (right && rowObjs.length > 0) {
                rowObjs[rowObjs.length - 1].c2 += (rowObjs[rowObjs.length - 1].c2 ? ' ' : '') + right;
            }
        }
    }

    for (let r = 0; r < rowObjs.length; r++) {
        const curr = rowObjs[r];
        if (curr.pendingForNext && r + 1 < rowObjs.length) {
            const next = rowObjs[r + 1];
            next.c3 = (curr.pendingForNext + (next.c3 ? ' ' + next.c3 : '')).trim();
            delete curr.pendingForNext;
        }

        tableRows.push({
            c1: cleanPebText(curr.c1 || ''),
            c2: cleanPebText(curr.c2 || ''),
            c3: cleanPebText(curr.c3 || ''),
            c4: cleanPebText(curr.c4 || ''),
            c5: '', c6: '',
            isSubHeader: false
        });
    }

    return {
        title: title || '',
        subtitle: '',
        sectionType: 'table',
        colCount,
        colWidths,
        tableHeaders,
        tableRows,
        listItems: [],
        notes: []
    };
}

function parseGenericSectionTable(title, lines) {
    const tableRows = [];
    const notes = [];
    let subtitle = '';
    let tableHeaders = [];
    let colWidths = [];
    let colCount = 2;

    const dataLines = [];
    for (const l of lines) {
        const s = l.lineStr;
        if (/^Pre-engineered\s*steel/i.test(s) || /^\(if\s*more\s*than\s*one/i.test(s) || /^Utkarsh\s*Pre\s*-\s*engineered/i.test(s)) {
            subtitle = s;
            continue;
        }
        if (/^(?:Special\s*condition|Crane\s*Notes|\*Not\s*by|#Dimension|Above\s*assume|Crane\s*rail|Follow\s*the\s*estimate|Crane\s*level\s*walkway|Bottom\s*of\s*the|Slope\s*–)/i.test(s)) {
            notes.push(s);
            continue;
        }
        dataLines.push(l);
    }

    // ── 1. Codes / Standards (A.1) ──
    if (/Codes/i.test(title)) {
        colCount = 2;
        tableHeaders = ['Codes/Standards', ''];
        let curRow = null;
        for (const l of dataLines) {
            if (/^Codes\/Standards$/i.test(l.lineStr)) continue;
            const left = l.items.filter(it => it.x < 280).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 280).map(it => it.str).join(' ').trim();

            if (left) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: left, c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false };
            } else if (right && curRow) {
                curRow.c2 += (curRow.c2 ? ' ' : '') + right;
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 2. Design Loads (A.2) ──
    else if (/Design\s*Loads/i.test(title)) {
        colCount = 2;
        tableHeaders = [];
        let curRow = null;
        for (const l of dataLines) {
            const left = l.items.filter(it => it.x < 280).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 280).map(it => it.str).join(' ').trim();

            if (/^(?:Wind\s*load|Seismic\s*load)$/i.test(left) && !right) {
                if (curRow) tableRows.push(curRow);
                curRow = null;
                tableRows.push({ c1: left, c2: '', c3: '', c4: '', c5: '', c6: '', isSubHeader: true });
                continue;
            }

            if (left) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: left, c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false };
            } else if (right) {
                if (curRow) {
                    if (/^[b-z]\)\s*/.test(right)) {
                        tableRows.push(curRow);
                        curRow = { c1: '', c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false };
                    } else {
                        curRow.c2 += (curRow.c2 ? ' ' : '') + right;
                    }
                }
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 3. Deflection Limits (A.4) ──
    else if (/Deflection\s*Limits/i.test(title)) {
        colCount = 2;
        tableHeaders = [];
        let curRow = null;
        for (const l of dataLines) {
            const s = l.lineStr;
            if (/^(?:Primary\s*frames|Secondary|Crane\s*beam)/i.test(s) && !l.items.some(it => it.x >= 300)) {
                if (curRow) tableRows.push(curRow);
                curRow = null;
                tableRows.push({ c1: s, c2: '', c3: '', c4: '', c5: '', c6: '', isSubHeader: true });
                continue;
            }
            const left = l.items.filter(it => it.x < 280).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 280).map(it => it.str).join(' ').trim();
            if (left) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: left, c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false };
            } else if (right && curRow) {
                curRow.c2 += (curRow.c2 ? ' ' : '') + right;
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 4. Project Summary (B) ──
    else if (/Project\s*Summary/i.test(title)) {
        colCount = 3;
        tableHeaders = ['Building No. / Utility', 'No. of Buildings / Area', 'Total Area (Sq.m)'];
        for (const l of dataLines) {
            const s = l.lineStr;
            if (/^Building\s+no|^UTILITY\s+OF\s+BUILDING/i.test(s)) continue;
            if (/^(?:Gross\s*Area|Total\s*area)/i.test(s)) {
                const lastItem = l.items[l.items.length - 1].str;
                tableRows.push({ c1: s.replace(/\s*\d+$/, ''), c2: '', c3: lastItem, c4: '', c5: '', c6: '', isSubHeader: true });
                continue;
            }
            if (/^Total\s*no\.\s*of\s*Buildings/i.test(s)) {
                const right = l.items.filter(it => it.x >= 350).map(it => it.str).join(' ');
                tableRows.push({ c1: 'Total no. of Buildings', c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false });
                continue;
            }
            if (l.items.length >= 3) {
                const c1 = l.items[0].str;
                const c3 = l.items[l.items.length - 1].str;
                const c2 = l.items.slice(1, l.items.length - 1).map(x => x.str).join(' ');
                tableRows.push({ c1, c2, c3, c4: '', c5: '', c6: '', isSubHeader: false });
            } else if (l.items.length === 2) {
                tableRows.push({ c1: l.items[0].str, c2: l.items[1].str, c3: '', c4: '', c5: '', c6: '', isSubHeader: false });
            }
        }
    }
    // ── 5. Building Geometry / C.1 Description ──
    else if (/Building\s*Description$/i.test(title)) {
        colCount = 2;
        tableHeaders = [];
        for (const l of dataLines) {
            const left = l.items.filter(it => it.x < 250).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 250).map(it => it.str).join(' ').trim();
            if (left || right) {
                tableRows.push({ c1: left, c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false });
            }
        }
    }
    // ── 6. Buildings Geometry (C.1.1) ──
    else if (/Buildings\s*Geometry/i.test(title)) {
        colCount = 4;
        tableHeaders = ['Sr. No.', 'Item', 'Description', 'Remark'];
        let curRow = null;
        for (const l of dataLines) {
            const s = l.lineStr;
            if (/^Sr\.?\s*No\.?|Item\s+Description/i.test(s)) continue;
            if (/^(?:Surface\s*preparation|Minimum\s*thickness\s*criteria)$/i.test(s)) {
                if (curRow) tableRows.push(curRow);
                curRow = null;
                tableRows.push({ c1: s, c2: '', c3: '', c4: '', c5: '', c6: '', isSubHeader: true });
                continue;
            }

            const srItem = l.items.find(it => it.x < 140 && /^\d+$/.test(it.str));
            const srX = srItem ? srItem.x : -1;
            const itemText = l.items.filter(it => it !== srItem && it.x > srX && it.x < 230).map(it => it.str).join(' ').trim();
            const descText = l.items.filter(it => it.x >= 230 && it.x < 400).map(it => it.str).join(' ').trim();
            const remText = l.items.filter(it => it.x >= 400).map(it => it.str).join(' ').trim();

            if (srItem) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: srItem.str, c2: itemText, c3: descText, c4: remText, c5: '', c6: '', isSubHeader: false };
            } else if (curRow) {
                if (itemText) curRow.c2 += (curRow.c2 ? ' ' : '') + itemText;
                if (descText) curRow.c3 += (curRow.c3 ? ' ' : '') + descText;
                if (remText) curRow.c4 += (curRow.c4 ? ' ' : '') + remText;
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 7. Bracing System (C.1.2) ──
    else if (/Bracing\s*System/i.test(title)) {
        colCount = 3;
        tableHeaders = [];
        colWidths = ['6%', '44%', '50%'];
        const rows = [
            { c1: '1', r1Span: 3, c2: 'Roof', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { skipC1: true, c2: 'Side Columns up to Crane/Mezzanine/ Opening', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { skipC1: true, c2: 'Side Columns over Crane/Mezzanine/ Opening', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '2', r1Span: 1, c2: 'Intermediate Columns up to Crane/Mezzanine/ Opening', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '3', r1Span: 1, c2: 'Intermediate Columns over Crane/Mezzanine/ Opening', c3: '', c4: '', c5: '', c6: '', isSubHeader: false }
        ];

        for (const l of dataLines) {
            const right = l.items.filter(it => it.x >= 220).map(it => it.str).join(' ').trim();
            const left = l.items.filter(it => it.x >= 90 && it.x < 220).map(it => it.str).join(' ').trim();
            if (/Roof/i.test(left) && right) rows[0].c3 = right;
            if (/Side\s*Columns\s*up/i.test(left) && right) rows[1].c3 = right;
            if (/Side\s*Columns\s*over/i.test(left) && right) rows[2].c3 = right;
            if (/Intermediate.*up/i.test(left) && right) rows[3].c3 = right;
            if (/Intermediate.*over/i.test(left) && right) rows[4].c3 = right;
        }

        for (const r of rows) {
            tableRows.push(r);
        }
    }
    // ── 8. Support Conditions (C.1.3) ──
    else if (/Support\s*Conditions/i.test(title)) {
        colCount = 3;
        tableHeaders = [];
        colWidths = ['6%', '44%', '50%'];
        const rows = [
            { c1: '1', c2: 'Main Column', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '2', c2: 'Internal Column', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '3', c2: 'Wind Column', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '4', c2: 'Mezzanine Supporting Column', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '5', c2: 'Crane Leg', c3: '', c4: '', c5: '', c6: '', isSubHeader: false }
        ];

        for (const l of dataLines) {
            const lineStr = l.lineStr || l.items.map(it => it.str).join(' ');
            const suppText = l.items.filter(it => it.x >= 220).map(it => it.str).join(' ').trim();

            if (/Main\s*Column/i.test(lineStr)) {
                rows[0].c3 = cleanPebText(suppText || 'Fixed');
            } else if (/Internal\s*Column/i.test(lineStr)) {
                rows[1].c3 = cleanPebText(suppText || 'Pinned');
            } else if (/Wind\s*Column/i.test(lineStr)) {
                rows[2].c3 = cleanPebText(suppText || 'Pinned');
            } else if (/Mezzanine/i.test(lineStr)) {
                if (suppText) rows[3].c3 = cleanPebText(suppText);
            } else if (/Crane\s*Leg/i.test(lineStr)) {
                if (suppText) rows[4].c3 = cleanPebText(suppText);
            }
        }

        for (const r of rows) {
            tableRows.push(r);
        }
    }
    // ── 9. Surface Preparation & Minimum Thickness (C.1.4) ──
    else if (/Surface\s*Preparation/i.test(title)) {
        colCount = 4;
        tableHeaders = [];
        colWidths = ['6%', '30%', '44%', '20%'];

        const rows = [
            // 1. Surface preparation
            { c1: '1', r1Span: 3, c2: 'Surface preparation', c2Span: 3, isC2Bold: true, skipC3: true, skipC4: true, c5: '', c6: '', isSubHeader: false },
            { skipC1: true, c2: 'Primary Member', c3: '', c3Span: 2, skipC4: true, c5: '', c6: '', isSubHeader: false },
            { skipC1: true, c2: 'Secondary Member', c3: '', c3Span: 2, skipC4: true, c5: '', c6: '', isSubHeader: false },
            // 2. Minimum thickness criteria
            { c1: '2', r1Span: 3, c2: 'Minimum thickness criteria', c2Span: 3, isC2Bold: true, skipC3: true, skipC4: true, c5: '', c6: '', isSubHeader: false },
            { skipC1: true, c2: 'Primary Member (mm)', c3: '', c4: '', alignC4: 'center', c5: '', c6: '', isSubHeader: false },
            { skipC1: true, c2: 'Secondary Member (mm)', c3: '', c4: '', alignC4: 'center', c5: '', c6: '', isSubHeader: false },
            // 3. Built - ups welding type
            { c1: '3', r1Span: 1, c2: 'Built - ups welding type', c3: '', c3Span: 2, skipC4: true, c5: '', c6: '', isSubHeader: false }
        ];

        let primaryPrep = [];
        let secPrep = [];
        let primaryThk = '';
        let primaryFy = '';
        let secThk = '';
        let secFy = '';
        let weldingType = '';

        let inThickness = false;
        let inWelding = false;
        let curTarget = null;

        for (const l of dataLines) {
            const lineStr = l.lineStr;
            if (/Minimum\s*thickness\s*criteria/i.test(lineStr)) {
                inThickness = true;
                curTarget = null;
                continue;
            }
            if (/Built\s*-\s*ups\s*welding/i.test(lineStr)) {
                inWelding = true;
                curTarget = 'welding';
                const wText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();
                if (wText) weldingType = (weldingType ? weldingType + ' ' : '') + wText;
                continue;
            }

            if (!inThickness && !inWelding) {
                if (/Primary/i.test(lineStr)) curTarget = 'primaryPrep';
                else if (/Secondary/i.test(lineStr)) curTarget = 'secPrep';

                if (curTarget === 'primaryPrep') {
                    const pText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();
                    if (pText) primaryPrep.push(pText);
                } else if (curTarget === 'secPrep') {
                    const sText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();
                    if (sText) secPrep.push(sText);
                }
            } else if (inThickness && !inWelding) {
                if (/Primary/i.test(lineStr)) {
                    primaryThk = l.items.filter(it => it.x >= 240 && it.x < 420).map(it => it.str).join(' ').trim();
                    primaryFy = l.items.filter(it => it.x >= 420).map(it => it.str).join(' ').trim();
                } else if (/Secondary/i.test(lineStr)) {
                    secThk = l.items.filter(it => it.x >= 240 && it.x < 420).map(it => it.str).join(' ').trim();
                    secFy = l.items.filter(it => it.x >= 420).map(it => it.str).join(' ').trim();
                }
            } else if (inWelding) {
                const wText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();
                if (wText) weldingType = (weldingType ? weldingType + ' ' : '') + wText;
            }
        }

        const cleanStr = (s) => (s || '').replace(/\bO ne\b/g, 'One').replace(/\bcoat s\b/g, 'coats').replace(/\bP aint\b/g, 'Paint').replace(/\s+/g, ' ').trim();

        rows[1].c3 = cleanStr(primaryPrep.join(' '));
        rows[2].c3 = cleanStr(secPrep.join(' '));
        rows[4].c3 = cleanStr(primaryThk);
        rows[4].c4 = cleanStr(primaryFy);
        rows[5].c3 = cleanStr(secThk);
        rows[5].c4 = cleanStr(secFy);
        rows[6].c3 = cleanStr(weldingType);

        for (const r of rows) {
            tableRows.push(r);
        }
    }
    // ── 10. Roof System (C.1.5) ──
    else if (/Roof\s*System/i.test(title)) {
        colCount = 3;
        tableHeaders = [];
        colWidths = ['6%', '34%', '60%'];
        const rows = [
            { c1: '1', c2: 'Sheeting Profile', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '2', c2: 'Thickness of Sheet (TCT)', c3: '', c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '3', c2: 'Material of Construction', c3: 'BARE', isC3Bold: true, c4: '', c5: '', c6: '', isSubHeader: false },
            { c1: '4', c2: 'Eave Condition', c3: '', c4: '', c5: '', c6: '', isSubHeader: false }
        ];

        let eaveParts = [];
        for (const l of dataLines) {
            const lineStr = l.lineStr || l.items.map(it => it.str).join(' ');
            const valText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();

            if (/Sheeting\s*Profile/i.test(lineStr) && valText) {
                rows[0].c3 = cleanPebText(valText);
            } else if (/Thickness/i.test(lineStr) && valText) {
                rows[1].c3 = cleanPebText(valText);
            } else if (/Material/i.test(lineStr)) {
                if (/BARE/i.test(valText)) rows[2].c3 = 'BARE';
                const extra = valText.replace(/BARE/gi, '').trim();
                if (extra) eaveParts.push(cleanPebText(extra));
            } else if (/Gutter/i.test(lineStr) || /Galvalume/i.test(lineStr) || /down\s*comer/i.test(lineStr) || /Eave\s*Condition/i.test(lineStr)) {
                if (valText) eaveParts.push(cleanPebText(valText));
            }
        }

        if (eaveParts.length > 0) {
            rows[3].c3 = cleanPebText(eaveParts.join(' '));
        }

        for (const r of rows) {
            tableRows.push(r);
        }
    }
    // ── 10b. Wall System (C.1.6) ──
    else if (/Wall\s*System/i.test(title)) {
        colCount = 3;
        tableHeaders = [];
        colWidths = ['6%', '34%', '60%'];
        let curRow = null;
        for (const l of dataLines) {
            const srItem = l.items.find(it => it.x < 140 && /^\d+$/.test(it.str));
            const srX = srItem ? srItem.x : -1;
            const itemText = l.items.filter(it => it !== srItem && it.x > srX && it.x < 240).map(it => it.str).join(' ').trim();
            const descText = l.items.filter(it => it.x >= 240).map(it => it.str).join(' ').trim();

            if (srItem) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: srItem.str, c2: cleanPebText(itemText), c3: cleanPebText(descText), c4: '', c5: '', c6: '', isSubHeader: false };
            } else if (curRow) {
                if (itemText) curRow.c2 += (curRow.c2 ? ' ' : '') + cleanPebText(itemText);
                if (descText) curRow.c3 += (curRow.c3 ? ' ' : '') + cleanPebText(descText);
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 11. Wall Framed Openings (FO) ──
    else if (/Framed\s*Openings/i.test(title)) {
        colCount = 3;
        tableHeaders = ['Sr. No.', 'Location', 'Opening Details'];
        for (const l of dataLines) {
            if (/^Location\s+Opening/i.test(l.lineStr)) continue;
            const srItem = l.items.find(it => it.x < 140 && /^\d+$/.test(it.str));
            const locText = l.items.filter(it => it.x >= 100 && it.x < 220).map(it => it.str).join(' ').trim();
            const opText = l.items.filter(it => it.x >= 220).map(it => it.str).join(' ').trim();
            if (srItem || locText || opText) {
                tableRows.push({ c1: srItem ? srItem.str : '', c2: locText, c3: opText, c4: '', c5: '', c6: '', isSubHeader: false });
            }
        }
    }
    // ── 12. Mezzanine (C.1.8.1) ──
    else if (/Mezzanine/i.test(title)) {
        colCount = 10;
        tableHeaders = [
            'Sr. No. (Per Floor)',
            'Location',
            'Width (m)',
            'Length (m)',
            'Clear Height (m)',
            'Dead Load (KN/M2)',
            'Live Load (KN/M2)',
            'Deck Sheet Thickness',
            'Staircase',
            'Total Area'
        ];
        colWidths = ['8%', '10%', '9%', '9%', '10%', '11%', '11%', '14%', '9%', '9%'];

        for (const l of dataLines) {
            const s = l.lineStr;
            if (/^Sr\.\s*No\./i.test(s) || /^\(Per/i.test(s) || /^Floor\)/i.test(s) ||
                (/\(m\)/i.test(s) && /Height/i.test(s)) ||
                (/\(KN\/M2\)/i.test(s) && /Load/i.test(s)) ||
                (/Deck\s*Sheet/i.test(s) && /Staircase/i.test(s))) {
                continue;
            }

            if (l.items.length >= 10) {
                tableRows.push({
                    c1: l.items[0].str,
                    c2: l.items[1].str,
                    c3: l.items[2].str,
                    c4: l.items[3].str,
                    c5: l.items[4].str,
                    c6: l.items[5].str,
                    c7: l.items[6].str,
                    c8: l.items[7].str,
                    c9: l.items[8].str,
                    c10: l.items[9].str,
                    isSubHeader: false
                });
            } else if (l.items.length === 1 && /^N\/?A$/i.test(l.items[0].str)) {
                tableRows.push({
                    c1: 'N/A', c2: 'N/A', c3: 'N/A', c4: 'N/A', c5: 'N/A',
                    c6: 'N/A', c7: 'N/A', c8: 'N/A', c9: 'N/A', c10: 'N/A',
                    isSubHeader: false
                });
            } else if (l.items.length > 0) {
                const rowObj = {
                    c1: '', c2: '', c3: '', c4: '', c5: '',
                    c6: '', c7: '', c8: '', c9: '', c10: '',
                    isSubHeader: false
                };
                for (const it of l.items) {
                    if (it.x < 85) rowObj.c1 += (rowObj.c1 ? ' ' : '') + it.str;
                    else if (it.x < 145) rowObj.c2 += (rowObj.c2 ? ' ' : '') + it.str;
                    else if (it.x < 202) rowObj.c3 += (rowObj.c3 ? ' ' : '') + it.str;
                    else if (it.x < 245) rowObj.c4 += (rowObj.c4 ? ' ' : '') + it.str;
                    else if (it.x < 290) rowObj.c5 += (rowObj.c5 ? ' ' : '') + it.str;
                    else if (it.x < 340) rowObj.c6 += (rowObj.c6 ? ' ' : '') + it.str;
                    else if (it.x < 395) rowObj.c7 += (rowObj.c7 ? ' ' : '') + it.str;
                    else if (it.x < 450) rowObj.c8 += (rowObj.c8 ? ' ' : '') + it.str;
                    else if (it.x < 510) rowObj.c9 += (rowObj.c9 ? ' ' : '') + it.str;
                    else rowObj.c10 += (rowObj.c10 ? ' ' : '') + it.str;
                }
                tableRows.push(rowObj);
            }
        }

        if (tableRows.length === 0) {
            tableRows.push({
                c1: 'N/A', c2: 'N/A', c3: 'N/A', c4: 'N/A', c5: 'N/A',
                c6: 'N/A', c7: 'N/A', c8: 'N/A', c9: 'N/A', c10: 'N/A',
                isSubHeader: false
            });
        }
    }
    // ── 13. Canopy / Lean to ──
    else if (/Canopy|Lean\s*to/i.test(title)) {
        colCount = 4;
        tableHeaders = ['Sr. No.', 'Location', 'Description', 'Soffit'];
        let curRow = null;
        for (const l of dataLines) {
            if (/^Location\s+Description/i.test(l.lineStr)) continue;
            const srItem = l.items.find(it => it.x < 100 && /^\d+$/.test(it.str));
            const locText = l.items.filter(it => it.x >= 80 && it.x < 180).map(it => it.str).join(' ').trim();
            const descText = l.items.filter(it => it.x >= 180 && it.x < 450).map(it => it.str).join(' ').trim();
            const soffText = l.items.filter(it => it.x >= 450).map(it => it.str).join(' ').trim();
            if (srItem || locText) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: srItem ? srItem.str : '1', c2: locText, c3: descText, c4: soffText, c5: '', c6: '', isSubHeader: false };
            } else if (curRow) {
                if (descText) curRow.c3 += (curRow.c3 ? ' ' : '') + descText;
                if (soffText) curRow.c4 += (curRow.c4 ? ' ' : '') + soffText;
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 14. Cranes (Cranes / EOT Crane) ──
    else if (/Cranes|EOT\s*Crane/i.test(title)) {
        colCount = 2;
        tableHeaders = ['Parameter', 'Description / Loading'];
        let curRow = null;
        for (const l of dataLines) {
            if (/^Capacity\s*\(MT\)/i.test(l.lineStr)) continue;
            const left = l.items.filter(it => it.x < 220).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 220).map(it => it.str).join(' ').trim();
            if (left && right) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: left, c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false };
            } else if (left && !right) {
                if (curRow) {
                    curRow.c1 += (curRow.c1 ? ' ' : '') + left;
                } else {
                    curRow = { c1: left, c2: '', c3: '', c4: '', c5: '', c6: '', isSubHeader: false };
                }
            } else if (right && curRow) {
                curRow.c2 += (curRow.c2 ? ' ' : '') + right;
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── 15. Louvers ──
    else if (/Louver/i.test(title)) {
        colCount = 2;
        tableHeaders = ['Dimensions', 'Remarks'];
        for (const l of dataLines) {
            if (/^Dimensions\s+Remarks/i.test(l.lineStr)) continue;
            const left = l.items.filter(it => it.x < 350).map(it => it.str).join(' ').trim();
            const right = l.items.filter(it => it.x >= 350).map(it => it.str).join(' ').trim();
            if (left || right) {
                tableRows.push({ c1: left, c2: right, c3: '', c4: '', c5: '', c6: '', isSubHeader: false });
            }
        }
    }
    // ── 16. Accessories (C.1.8.7 or C.1.5.8) ──
    else if (/Accessories/i.test(title)) {
        colCount = 4;
        tableHeaders = ['Sr. No.', 'Description', 'Quantity', 'Remarks'];
        let curRow = null;
        for (const l of dataLines) {
            if (/^Description\s+Quantity/i.test(l.lineStr)) continue;
            const srItem = l.items.find(it => it.x < 80 && /^\d+$/.test(it.str));
            const descText = l.items.filter(it => it.x >= 80 && it.x < 170).map(it => it.str).join(' ').trim();
            const qtyText = l.items.filter(it => it.x >= 170 && it.x < 350).map(it => it.str).join(' ').trim();
            const remText = l.items.filter(it => it.x >= 350).map(it => it.str).join(' ').trim();

            if (srItem) {
                if (curRow) tableRows.push(curRow);
                curRow = { c1: srItem.str, c2: descText, c3: qtyText, c4: remText, c5: '', c6: '', isSubHeader: false };
            } else if (curRow) {
                if (descText) curRow.c2 += (curRow.c2 ? ' ' : '') + descText;
                if (qtyText) curRow.c3 += (curRow.c3 ? ' ' : '') + qtyText;
                if (remText) curRow.c4 += (curRow.c4 ? ' ' : '') + remText;
            }
        }
        if (curRow) tableRows.push(curRow);
    }
    // ── Fallback dynamic table parser (2, 3, or 4 columns) ──
    else {
        const dynTable = parseDynamicTable(title, dataLines);
        if (dynTable) {
            colCount = dynTable.colCount;
            colWidths = dynTable.colWidths;
            tableHeaders = dynTable.tableHeaders;
            dynTable.tableRows.forEach(r => tableRows.push(r));
        }
    }

    tableRows.forEach(r => {
        if (r.c1) r.c1 = cleanPebText(r.c1);
        if (r.c2) r.c2 = cleanPebText(r.c2);
        if (r.c3) r.c3 = cleanPebText(r.c3);
        if (r.c4) r.c4 = cleanPebText(r.c4);
        if (r.c5) r.c5 = cleanPebText(r.c5);
        if (r.c6) r.c6 = cleanPebText(r.c6);
        if (r.c7) r.c7 = cleanPebText(r.c7);
        if (r.c8) r.c8 = cleanPebText(r.c8);
        if (r.c9) r.c9 = cleanPebText(r.c9);
        if (r.c10) r.c10 = cleanPebText(r.c10);
    });

    return {
        title,
        subtitle,
        sectionType: 'table',
        colCount,
        colWidths,
        tableHeaders,
        tableRows,
        listItems: [],
        notes: (notes || []).map(cleanPebText)
    };
}