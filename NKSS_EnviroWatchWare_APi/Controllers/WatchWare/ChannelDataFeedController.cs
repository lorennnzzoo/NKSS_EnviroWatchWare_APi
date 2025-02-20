using Models;
using DashBoard = Models.DashBoard;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("ChannelDataFeed")]
    public class ChannelDataFeedController : ApiController
    {
        private readonly ChannelDataFeedService channel_data_feed_service;
        private readonly ReportService report_service;
        public ChannelDataFeedController(ChannelDataFeedService _channel_data_feed_service, ReportService _report_service)
        {
            channel_data_feed_service = _channel_data_feed_service;
            report_service = _report_service;
        }


        [HttpGet]
        [Route("Get24HourTrendForStation")]
        public IHttpActionResult Get24HourTrendForStation(int id)
        {
            try
            {
                var twentyFourHourTrend = report_service.Get24HourTrendForStation(id);
                if (twentyFourHourTrend == null)
                    return NotFound();
                return Ok(twentyFourHourTrend);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetStationFeed")]
        public IHttpActionResult GetStationFeed(int id)
        {
            try
            {
                var stationfeed = channel_data_feed_service.GetStationFeed(id);
                if (stationfeed == null)
                    return NotFound();
                return Ok(stationfeed);
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

        //[HttpGet]
        //[Route("GetStations")]

        //public IHttpActionResult GetStationNames()
        //{
        //    try
        //    {
        //        var stationNames = channel_data_feed_service.GetStations();
        //        if (stationNames == null)
        //            return NotFound();
        //        return Ok(stationNames);
        //    }
        //    catch (Exception ex)
        //    {
        //        var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
        //        {
        //            Content = new StringContent(ex.ToString())
        //        };

        //        return ResponseMessage(response);
        //    }
        //}
    }
}
