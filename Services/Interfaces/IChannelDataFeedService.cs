using DashBoard = Models.DashBoard;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IChannelDataFeedService
    {
        List<DashBoard.ChannelDataFeedByStation> GetAllStationsFeed();

        void InsertChannelData(int channelId, decimal channelValue, DateTime datetime, string passPhrase);
    }
}
