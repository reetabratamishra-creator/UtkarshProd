public class CurrencyInWords {
    
    private static final List<String> units = new List<String>{
        '', 'One', 'Two', 'Three', 'Four', 'Five',
        'Six', 'Seven', 'Eight', 'Nine', 'Ten',
        'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
        'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen',
        'Nineteen'
    };

    private static final List<String> tens = new List<String>{
        '', '', 'Twenty', 'Thirty', 'Forty',
        'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    };

    /*
     * Converts amount into Indian Rupee words
     * Example:
     * 123.45 =>
     * One Hundred and Twenty-Three Rupees and Forty-Five Paise Only
     */
    public static String convertToIndianRupees(Decimal amount) {

        if (amount == null || amount == 0) {
            return 'Zero Rupees Only';
        }

        Long rupees = amount.longValue();
        Long paisa = ((amount - rupees) * 100).round();

        String result = convertNumberToWords(rupees) + ' Rupees';

        if (paisa > 0) {
            result += ' and ' + convertNumberToWords(paisa) + ' Paise';
        }

        return result + ' Only';
    }

    /*
     * Converts number into words only
     * Example:
     * 80 => Eighty
     * 125 => One Hundred and Twenty-Five
     */
    public static String convertNumberOnly(Decimal amount) {

        if (amount == null || amount == 0) {
            return 'Zero';
        }

        return convertNumberToWords(amount.longValue());
    }

    /*
     * Core number conversion logic
     */
    private static String convertNumberToWords(Long n) {

        if (n < 20) {
            return units[n.intValue()];
        }

        if (n < 100) {
            Integer tenPart = n.intValue() / 10;
            Integer unitPart = Math.mod(n, 10).intValue();

            return tens[tenPart] + (unitPart > 0 ? '-' + units[unitPart] : '');
        }

        if (n < 1000) {
            return units[n.intValue() / 100] + 
                   ' Hundred' + 
                   (Math.mod(n, 100) > 0 ? ' and ' + convertNumberToWords(Math.mod(n, 100)) : '');
        }

        if (n < 100000) {
            return convertNumberToWords(n / 1000) + 
                   ' Thousand' + 
                   (Math.mod(n, 1000) > 0 ? ' ' + convertNumberToWords(Math.mod(n, 1000)) : '');
        }

        if (n < 10000000) {
            return convertNumberToWords(n / 100000) + 
                   ' Lakh' + 
                   (Math.mod(n, 100000) > 0 ? ' ' + convertNumberToWords(Math.mod(n, 100000)) : '');
        }

        return convertNumberToWords(n / 10000000) + 
               ' Crore' + 
               (Math.mod(n, 10000000) > 0 ? ' ' + convertNumberToWords(Math.mod(n, 10000000)) : '');
    }
}