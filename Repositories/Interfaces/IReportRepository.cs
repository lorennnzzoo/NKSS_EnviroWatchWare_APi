using Models.Report;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface IReportRepository
    {
        List<Data> GenerateRawDataReportForChannel(int ChannelId, DateTime From, DateTime To);
        List<Data> Generate15MinsAvgReportForChannel(int ChannelId, DateTime From, DateTime To);
        List<Data> Generate1HourAvgReportForChannel(int ChannelId, DateTime From, DateTime To);
        List<Data> Generate12HourAvgReportForChannel(int ChannelId, DateTime From, DateTime To);
        List<Data> Generate24HourAvgReportForChannel(int ChannelId, DateTime From, DateTime To);

        List<Data> GenerateMonthAvgReportForChannel(int ChannelId, DateTime From, DateTime To);
        List<Data> GenerateSixMonthAvgReportForChannel(int ChannelId, DateTime From, DateTime To);
        List<Data> GenerateYearAvgReportForChannel(int ChannelId, DateTime From, DateTime To);
    }
}
