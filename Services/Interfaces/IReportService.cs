

using System;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IReportService
    {
        Models.Report.ReportData GetReport(Models.Post.Report.ReportFilter filter);

        List<Models.Report.Data> GenerateReport(int ChannelId, Models.Post.Report.DataAggregationType dataAggregationType,DateTime From,DateTime To);
        Models.Report.Selection.SelectionModel GetSelectionModel();
    }
}
