var prompt = $v("P2_PROMPT");
if (!prompt) { alert("Please enter a question."); return; }

$("#query-result-container").html('<p>Loading...</p>');
$s("P2_SQL_QUERY", "");


apex.server.process("GET_QUERY_RESULT", {
    x01: prompt
}, {
    success: function(data) {
        if (data.error) {
            $("#query-result-container").html(
                '<p style="color:red;">Error: ' + data.error + '</p>'
            );
            return;
        }

        
        $s("P2_SQL_QUERY", data.sql);

        
        var html = '<table class="t-Report-report" style="width:100%;border-collapse:collapse;">';
      
        html += '<thead><tr>';
        data.columns.forEach(function(col) {
            html += '<th style="border:1px solid #ccc;padding:8px;background:#f5f5f5;">' + col + '</th>';
        });
        html += '</tr></thead>';

        html += '<tbody>';
        if (data.rows.length === 0) {
            html += '<tr><td colspan="' + data.columns.length + 
                    '" style="text-align:center;padding:8px;">No data found</td></tr>';
        }
        data.rows.forEach(function(row) {
            html += '<tr>';
            row.forEach(function(cell) {
                html += '<td style="border:1px solid #ccc;padding:8px;">' + 
                        (cell || '') + '</td>';
            });
            html += '</tr>';
        });
        html += '</tbody></table>';
        html += '<p style="margin-top:8px;color:#666;">Total rows: ' + data.rows.length + '</p>';

        $("#query-result-container").html(html);
    },
    dataType: "json"
});