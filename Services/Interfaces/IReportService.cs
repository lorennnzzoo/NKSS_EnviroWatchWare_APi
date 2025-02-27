

using Models.Report;
using System;
using System.Collections.Generic;
using System.Data;

namespace Services.Interfaces
{
    public interface IReportService
    {
        List<Dictionary<string, object>> GetReport(Models.Post.Report.ReportFilter filter);
        DataTable GenerateReport(List<int> ChannelIds, Models.Post.Report.ReportType reportType, Models.Post.Report.DataAggregationType dataAggregationType, DateTime From, DateTime To);
        List<Dictionary<string, object>> TransformTableToList(DataTable dataTable);
        List<Dictionary<string, object>> TransformAverageTableToList(DataTable dataTable);
        Models.Report.Selection.SelectionModel GetSelectionModel();
    }
}
