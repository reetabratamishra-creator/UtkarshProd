/*
Owner - Ayantika 
CLASS: TenderDepartmentUtilForNotification

Takes the department name from the input.
Removes extra spaces and converts it to uppercase for matching.
Checks the department against a predefined map.
Converts the department name into the standard department value, e.g. STEEL PIPES → Steel_Pipes_Department.
Returns the original cleaned name if no matching department is found.
This class is mainly used to keep department names consistent for notification processing.
*/
public class TenderDepartmentUtilForNotification {
    
    public static String normalizeDept(String rawDept) {
        if (String.isBlank(rawDept)) {
            return rawDept;
        }
        String key = rawDept.trim().toUpperCase();
        Map<String, String> deptMap = getDeptNormalizationMap();
        return deptMap.containsKey(key) ? deptMap.get(key) : rawDept.trim();
    }
    
    public static Map<String, String> getDeptNormalizationMap() {
        return new Map<String, String>{
            'HIGH MAST & POLYGONAL' => 'High_Mast_Department',
                'CRASH BARRIER' => 'Crash_Barrier_Department',
                'HDPE' => 'HDPE_Pipe_Department',
                'STEEL TUBULAR POLES' => 'Steel_Tubular_Pole_Department',
                'POLYMER' => 'PVC',
                'TRANSMISSION & TELECOM TOWER' => 'Transmission_Tower_Department',
                'PRE ENGINEERING BUILDING' => 'PEB',
                'SOLAR STRUCTURE' => 'Solar_Structure_Department',
                'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
                'STEEL PIPES' => 'Steel_Pipes_Department'
                };
                    }
}