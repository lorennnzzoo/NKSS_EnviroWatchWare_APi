using DashBoard = Models.DashBoard;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data;

namespace Services.Interfaces
{
    public interface IChannelDataFeedService
    {
        List<DashBoard.ChannelDataFeed> GetStationFeed(int stationId);

        void InsertChannelData(int channelId, decimal channelValue, DateTime datetime, string passPhrase);

        void InsertBulkData(DataTable bulkData);

        //List<Models.Station> GetStations();
    }
}
