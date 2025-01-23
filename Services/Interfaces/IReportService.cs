

using Models.Report;
using System;
using System.Collections.Generic;
using System.Data;

namespace Services.Interfaces
{
    public interface IReportService
    {
        List<ChannelDataResult> GetReport(Models.Post.Report.ReportFilter filter);

        DataTable GenerateReport(List<int> ChannelIds, Models.Post.Report.DataAggregationType dataAggregationType,DateTime From,DateTime To);
        List<ChannelDataResult> TransformDataTableToChannelDataResult(DataTable dataTable);
        Models.Report.Selection.SelectionModel GetSelectionModel();
    }
}
