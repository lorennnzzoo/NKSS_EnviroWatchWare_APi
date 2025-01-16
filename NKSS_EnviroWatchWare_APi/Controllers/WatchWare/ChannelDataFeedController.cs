using Models;
using DashBoard = Models.DashBoard;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [RoutePrefix("ChannelDataFeed")]
    public class ChannelDataFeedController : ApiController
    {
        private readonly ChannelDataFeedService channel_data_feed_service;
        public ChannelDataFeedController(ChannelDataFeedService _channel_data_feed_service)
        {
            channel_data_feed_service = _channel_data_feed_service;
        }

        [HttpGet]
        [Route("GetStationsFeed")]
        public IHttpActionResult GetStationsFeed()
        {
            try
            {
                var stationsfeed = channel_data_feed_service.GetAllStationsFeed();
                if (stationsfeed == null)
                    return NotFound();
                return Ok(stationsfeed);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
